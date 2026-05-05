FROM teddysun/xray:latest

RUN apk update && apk add --no-cache nginx supervisor && \
    mkdir -p /usr/share/nginx/html /tmp && \
    rm -rf /var/cache/apk/*

COPY config.json      /etc/xray/config.json
COPY nginx.conf       /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY index.html       /usr/share/nginx/html/index.html
COPY maintenance.html /usr/share/nginx/html/maintenance.html
COPY entrypoint.sh    /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
