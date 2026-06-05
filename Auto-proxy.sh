#!/bin/bash

cd /home/user/ansible
source venv/ansible/bin/activate
cat << EOF > playbook1_keepalived.yml
- name: Install and settings keepalived for HA1-COD and HA2-COD
  hosts: proxy
  become: true

  tasks:
    - name: Install package 'keepalived'
      community.general.apt_rpm:
        name: "keepalived"
        state: present
        update_cache: true

- hosts: ha1-cod
  become: true

  tasks:
    - name: Copy the 'keepalived.conf' file for MASTER
      ansible.builtin.template:
        src: templates/keepalived-master.conf.j2
        dest: /etc/keepalived/keepalived.conf
        owner: root
        group: root
        mode: '0644'

- hosts: ha2-cod
  become: true

  tasks:
    - name: Copy the 'keepalived.conf' file for BACKUP
      ansible.builtin.template:
        src: templates/keepalived-backup.conf.j2
        dest: /etc/keepalived/keepalived.conf
        owner: root
        group: root
        mode: '0644'

- hosts: proxy
  become: true

  tasks:
    - name: Started and enabled keepalived
      ansible.builtin.systemd:
        name: keepalived
        state: started
        enabled: true
EOF
mkdir templates
cat <<EOF > templates/keepalived-master.conf.j2
global_defs {
    enable_script_security
    max_auto_priority
}

vrrp_script chk_haproxy {
  script "killall -0 haproxy"
  interval 2
  weight 2
}

vrrp_instance VI_1 {
  interface {{ keepalived_interface_name }}
  state MASTER

  virtual_router_id 51
  priority 101

  virtual_ipaddress {
    {{ keepalived_virtual_ipaddress }}
  }

  track_script {
    chk_haproxy
  }
}
EOF

cat <<EOF > templates/keepalived-backup.conf.j2
global_defs {
    enable_script_security
    max_auto_priority
}

vrrp_script chk_haproxy {
  script "killall -0 haproxy"
  interval 2
  weight 2
}

vrrp_instance VI_1 {
  interface {{ keepalived_interface_name }}
  state BACKUP

  virtual_router_id 51
  priority 100

  virtual_ipaddress {
    {{ keepalived_virtual_ipaddress }}
  }

  track_script {
    chk_haproxy
  }
}
EOF

cat <<EOF > inventories/production/group_vars/proxy.yml
keepalived_interface_name: "ens1"
keepalived_virtual_ipaddress: "172.16.1.253/23"
EOF

cat <<EOF > playbook2_web.yml
---
- name: Install Installing the Angie Web Server
  hosts: server
  become: true
  
  tasks:
    - name: Install package 'angie'
      community.general.apt_rpm:
        name: "angie"
        state: present
        update_cache: true
        
    - name: Copy the 'index.html' file
      ansible.builtin.template:
        src: templates/index.html.j2
        dest: /usr/share/angie/html/index.html
        owner: root
        group: root
        mode: '0644'
        
    - name: Started and enabled angie
      ansible.builtin.systemd:
        name: angie
        state: started
        enabled: true
EOF

cat <<EOF > templates/index.html.j2
<html>
   <head>
      <title>AU_Team</title>
   </head>
   <body>
      <h1>{{ ansible_facts['hostname'] }} by Angie!</h1>
   </body>
</html>
EOF

cat <<EOF > playbook3_haproxy.yml
---
- name: Install and settings haproxy for HA1-COD and HA2-COD
  hosts: proxy
  become: true

  tasks:
    - name: Install package 'haproxy'
      community.general.apt_rpm:
        name: "haproxy"
        state: present
        update_cache: true

    - name: Copy the 'haproxy.cfg' file
      ansible.builtin.template:
        src: templates/haproxy.cfg.j2
        dest: /etc/haproxy/haproxy.cfg
        owner: root
        group: root
        mode: '0644'

    - name: Started and enabled haproxy
      ansible.builtin.systemd:
        name: haproxy
        state: started
        enabled: true
EOF

cat <<EOF > templates/haproxy.cfg.j2
global
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    daemon

defaults
    log     global
    mode    http
    retries 2
    timeout client 30m
    timeout connect 4s
    timeout server 30m
    timeout check 5s

frontend main
    bind {{ haproxy_frontend_bind_address }}:{{ haproxy_frontend_bind_port }}
    default_backend             app

backend app
    balance     roundrobin
    option httpchk GET /
    http-request set-header X-Forwarded-For %[src]
    http-request set-header X-Forwarded-Proto http
{% for record in haproxy_backend_add_hosts %}
    server {{ record.name }} {{ record.address }}:80 check
{% endfor %}

listen stats
    bind *:9000
    mode http
    stats enable
    stats hide-version
    stats realm Haproxy\ Statistics
    stats uri /haproxy_stats
EOF

cat <<EOF >> inventories/production/group_vars/proxy.yml

haproxy_frontend_bind_address: "0.0.0.0"
haproxy_frontend_bind_port: "80"
haproxy_backend_add_hosts:
  - name: "srv1-cod"
    address: "172.16.1.1"
  - name: "srv2-cod"
    address: "172.16.1.2"
  - name: "srv3-cod"
    address: "172.16.1.3"
EOF

for i in ha1 ha2 srv1 srv2 srv3;
do
ping -c3 $i-cod
done
