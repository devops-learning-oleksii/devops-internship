FROM gradle:6.9.4-jdk11 AS build-stage

COPY ./backend /backend

ARG DATABASE
ARG USERNAME
ARG USERPASSWORD

RUN sed -i "s|hibernate.connection.url=.*|hibernate.connection.url=jdbc:postgresql://postgres:5432/${DATABASE}|" /backend/src/main/resources/hibernate.properties && \
    sed -i "s|hibernate.connection.username=.*|hibernate.connection.username=${USERNAME}|" /backend/src/main/resources/hibernate.properties && \
    sed -i "s|hibernate.connection.password=.*|hibernate.connection.password=${USERPASSWORD}|" /backend/src/main/resources/hibernate.properties

WORKDIR /backend

RUN gradle build

FROM tomcat:9-jre11 as production-stage

RUN rm -rf /usr/local/tomcat/webapps/
COPY --from=build-stage /backend/build/libs/*.war /usr/local/tomcat/webapps/ROOT.war

CMD ["catalina.sh", "run"]
