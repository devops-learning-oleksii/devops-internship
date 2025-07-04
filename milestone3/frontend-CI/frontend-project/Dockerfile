FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html

COPY ./build/ /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

ENV DOMAIN_TOKEN=DOMAIN_TOKEN

COPY entry.sh /conf/entry.sh
RUN chmod +x /conf/entry.sh
ENTRYPOINT ["/conf/entry.sh"]

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]