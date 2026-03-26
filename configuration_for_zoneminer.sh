docker run -d --name="Zoneminder" \
--net="bridge" \
--privileged="false" \
--shm-size="5G" \
-p 8443:443/tcp \
-p 8080:80/tcp \
-p 9000:9000/tcp \
-e TZ="Asia/Yekaterinburg" \
-e PUID="99" \
-e PGID="100" \
-v "/mnt/Zoneminder":"/config":rw \
-v "/mnt/Zoneminder/data":"/var/cache/zoneminder":rw \
dlandon/zoneminder
