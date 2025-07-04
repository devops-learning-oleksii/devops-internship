#!/bin/sh
set -e
STATIC_FILE=$(find /usr/share/nginx/html/static/js -type f -name "main.*.js" | head -n 1)
echo "FOUND file: ${STATIC_FILE}"
if [ -n "${STATIC_FILE}" ] && [ -f "${STATIC_FILE}" ]; then
    sed -i "s|DOMAIN_TOKEN|${DOMAIN_TOKEN}|g" "${STATIC_FILE}"
else
    echo "File main..js not found!"
fi

exec "$@"