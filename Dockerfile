FROM teddysun/xray:latest

RUN apk add --no-cache nginx supervisor && \
    mkdir -p /var/lib/nginx/html /tmp

COPY config.json      /etc/xray/config.json
COPY nginx.conf       /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY index.html       /index.html
COPY maintenance.html /maintenance.html
COPY entrypoint.sh    /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]
