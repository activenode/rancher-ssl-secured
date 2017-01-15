FROM nginx
ENV SSL_PORT ${SSL_PORT:-9383}

RUN mkdir /etc/nginx/certs
RUN apt-get update && apt-get install vim -y

#Now generating a test ssl cert to be able to access initially via SSL
#Please replace this asap for production (e.g. by symlinking the files in the volume [/etc/nginx/certs])
RUN openssl req \
    -new \
    -newkey rsa:4096 \
    -days 365 \
    -nodes \
    -x509 \
    -subj "/C=US/ST=DEV/L=developer_land/O=DOCKER/CN=invalidhost.inv" \
    -keyout /etc/nginx/certs/custom.key \
    -out /etc/nginx/certs/custom.crt

#Adding supersmall ssl server configuration to proxy the other container
RUN echo 'server { \n\
    listen       '"$SSL_PORT"' ssl;\n\
    server_name localhost;\n\
\n\
    ssl    on;\n\
    ssl_certificate    /etc/nginx/certs/custom.crt;\n\
    ssl_certificate_key    /etc/nginx/certs/custom.key;\n\
\n\
        location / {\n\
        resolver 127.0.0.1 valid=30s;\n\
        proxy_set_header        Host               $host;\n\
                proxy_set_header        X-Real-IP          $remote_addr;\n\
                proxy_set_header        X-Forwarded-For    $proxy_add_x_forwarded_for;\n\
                proxy_set_header        X-Forwarded-Host   $host:$server_port;\n\
                proxy_set_header        X-Forwarded-Port   $server_port;\n\
                proxy_set_header        X-Forwarded-Proto  https;\n\
        proxy_pass http://rancherserver:8080;\n\
    }\n\
}' > /etc/nginx/conf.d/default.conf


#The dependent server can take some time
#That is why a sleep of 10seconds is added.
#This may not be required with params like depends_on but can
#be helpful in other situations
#This is done because --link is deprecated as of now and we need to work with the network only
RUN echo '#!/bin/bash\n\
sleep 10\n\
nginx -g "daemon off;"' > /etc/nginx/run-nginx.sh

RUN chmod +x /etc/nginx/run-nginx.sh

VOLUME /etc/nginx/certs

CMD ["/etc/nginx/run-nginx.sh"]
