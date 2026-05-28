terraform {
  required_providers {
    freeipa = {
      source  = "camptocamp/freeipa"
      version = "1.0.0"
    }
  }
}

provider "freeipa" {
  host     = "srv-hq.au.team"
  username = "admin"
  password = "P@ssw0rd"
}

resource "freeipa_dns_zone" "reverse_zone_1_1_10" {
  zone_name = "1.1.10.in-addr.arpa."
}

resource "freeipa_dns_zone" "reverse_zone_2_1_10" {
  zone_name = "2.1.10.in-addr.arpa."
}

resource "freeipa_dns_zone" "reverse_zone_2_10" {
  zone_name = "2.10.in-addr.arpa."
}

resource "freeipa_dns_zone" "reverse_zone_16_172" {
  zone_name = "16.172.in-addr.arpa."
}

resource "freeipa_dns_record" "au_team_srv-hq" {
  dnszoneidnsname = "au.team."
  idnsname        = "srv-hq"
  records         = ["10.1.1.10"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_fw-hq" {
  dnszoneidnsname = "au.team."
  idnsname        = "fw-hq"
  records         = ["10.1.1.1]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_adm-hq" {
  dnszoneidnsname = "au.team."
  idnsname        = "adm-hq"
  records         = ["10.1.1.46"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_fw-br" {
  dnszoneidnsname = "au.team."
  idnsname        = "fw-br"
  records         = ["10.2.0.2"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_srv-br" {
  dnszoneidnsname = "au.team."
  idnsname        = "srv-br"
  records         = ["10.2.1.10"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_cli-br" {
  dnszoneidnsname = "au.team."
  idnsname        = "cli-br"
  records         = ["10.2.2.2"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_rtr-br" {
  dnszoneidnsname = "au.team."
  idnsname        = "rtr-br"
  records         = ["10.2.0.1"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_rtr-cod" {
  dnszoneidnsname = "au.team."
  idnsname        = "rtr-cod"
  records         = ["172.16.1.254"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_srv1-cod" {
  dnszoneidnsname = "au.team."
  idnsname        = "srv1-cod"
  records         = ["172.16.1.1"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_srv2-cod" {
  dnszoneidnsname = "au.team."
  idnsname        = "srv2-cod"
  records         = ["172.16.1.2"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_srv3-cod" {
  dnszoneidnsname = "au.team."
  idnsname        = "srv3-cod"
  records         = ["172.16.1.3"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_ha1-cod" {
  dnszoneidnsname = "au.team."
  idnsname        = "ha1-cod"
  records         = ["172.16.0.1"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_sw-cod" {
  dnszoneidnsname = "au.team."
  idnsname        = "sw-cod"
  records         = ["172.16.1.0"]
  type            = "A"
}

resource "freeipa_dns_record" "au_team_ha2-cod" {
  dnszoneidnsname = "au.team."
  idnsname        = "ha2-cod"
  records         = ["172.16.0.2"]
  type            = "A"
}

resource "freeipa_dns_record" "a_record_reverse_zone" {
  dnszoneidnsname = "1.1.10.in-addr.arpa."
  idnsname        = "1"
  records         = ["fw-hq.au.team."]
  type            = "PTR"
}

resource "freeipa_dns_record" "b_record_reverse_zone" {
  dnszoneidnsname = "1.1.10.in-addr.arpa."
  idnsname        = "46"
  records         = ["adm-hq.au.team."]
  type            = "PTR"
}

resource "freeipa_dns_record" "c_record_reverse_zone" {
  dnszoneidnsname = "2.10.in-addr.arpa."
  idnsname        = "1.0"
  records         = ["rtr-br.au.team."]
  type            = "PTR"
}

resource "freeipa_dns_record" "d_record_reverse_zone" {
  dnszoneidnsname = "2.10.in-addr.arpa."
  idnsname        = "2.0"
  records         = ["fw-br.au.team."]
  type            = "PTR"
}

resource "freeipa_dns_record" "e_record_reverse_zone" {
  dnszoneidnsname = "2.10.in-addr.arpa."
  idnsname        = "10.1"
  records         = ["srv-br.au.team."]
  type            = "PTR"
}

resource "freeipa_dns_record" "f_record_reverse_zone" {
  dnszoneidnsname = "16.172.in-addr.arpa."
  idnsname        = "1.1"
  records         = ["srv1-cod.au.team."]
  type            = "PTR"
}

resource "freeipa_dns_record" "g_record_reverse_zone" {
  dnszoneidnsname = "16.172.in-addr.arpa."
  idnsname        = "2.1"
  records         = ["srv2-cod.au.team."]
  type            = "PTR"
}

resource "freeipa_dns_record" "h_record_reverse_zone" {
  dnszoneidnsname = "16.172.in-addr.arpa."
  idnsname        = "3.1"
  records         = ["srv3-cod.au.team."]
  type            = "PTR"
}

resource "freeipa_dns_record" "i_record_reverse_zone" {
  dnszoneidnsname = "16.172.in-addr.arpa."
  idnsname        = "2.0"
  records         = ["ha2-cod.au.team."]
  type            = "PTR"
}

resource "freeipa_dns_record" "k_record_reverse_zone" {
  dnszoneidnsname = "16.172.in-addr.arpa."
  idnsname        = "1.0"
  records         = ["ha1-cod.au.team."]
  type            = "PTR"
}
