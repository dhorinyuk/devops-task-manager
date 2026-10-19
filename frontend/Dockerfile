FROM nginx:1.27-alpine

RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html styles.css app.js config.js /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
