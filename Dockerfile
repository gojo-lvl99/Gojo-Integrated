FROM nginx:alpine

RUN apk add --no-cache supervisor curl unzip

RUN curl -Lo /tmp/xray.zip \
    https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
    && unzip /tmp/xray.zip -d /usr/local/bin xray \
    && chmod +x /usr/local/bin/xray \
    && rm /tmp/xray.zip

COPY config.json      /etc/xray/config.json
COPY nginx.conf       /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisord.conf
COPY index.html       /usr/share/nginx/html/index.html
COPY maintenance.html /usr/share/nginx/html/maintenance.html
COPY entrypoint.sh    /entrypoint.sh

RUN chmod +x /entrypoint.sh && mkdir -p /tmp

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]

