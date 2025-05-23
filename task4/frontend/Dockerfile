FROM node:14-alpine AS build-stage

COPY ./frontend /frontend

WORKDIR /frontend

ARG BACKEND_IP
ENV REACT_APP_API_BASE_URL=http://${BACKEND_IP}:8080/

RUN npm install
RUN npm run build

FROM nginx:alpine AS production-stage

RUN rm -rf /usr/share/nginx/html

WORKDIR /usr/share/nginx/html
COPY --from=build-stage /frontend/build .
COPY nginx.conf /etc/nginx/nginx.conf
CMD ["nginx", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]
