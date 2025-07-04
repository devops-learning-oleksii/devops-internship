#!/bin/sh
set -e
HIBERNATE_FILE=$(find /opt/tomcat/webapps/ROOT/WEB-INF/classes/ -type f -name "hibernate.properties" | head -n 1)
echo "FOUND file: ${HIBERNATE_FILE}"
if [ -n "${HIBERNATE_FILE}" ] && [ -f "${HIBERNATE_FILE}" ]; then
    sed -i -e "s|DB_ENDPOINT_TOKEN|${DB_ENDPOINT_TOKEN}|g" \
    -e "s|DB_NAME_TOKEN|${DB_NAME_TOKEN}|g" \
    -e "s|DB_USERNAME_TOKEN|${DB_USERNAME_TOKEN}|g" \
    -e "s|DB_USERPASSWORD_TOKEN|${DB_USERPASSWORD_TOKEN}|g" "${HIBERNATE_FILE}" 
else
    echo "File hibernate.properties not found!"
fi
CACHE_FILE=$(find /opt/tomcat/webapps/ROOT/WEB-INF/classes/ -type f -name "cache.properties" | head -n 1)
echo "FOUND file: ${CACHE_FILE}"
if [ -n "${CACHE_FILE}" ] && [ -f "${CACHE_FILE}" ]; then

    sed -i "s|REDIS_ENDPOINT_TOKEN|${REDIS_ENDPOINT_TOKEN}|g" "${CACHE_FILE}"
else
    echo "File cache.properties not found!"
fi

exec "$@"