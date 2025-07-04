#!/bin/sh
set -e
FILE=/etc/grafana/provisioning/alerting/contact-points.yaml
echo "Found file: ${FILE}"
if [ -n "${FILE}" ] && [ -f "${FILE}" ]; then
    sed -i "s|DISCORD_WEBHOOK_TOKEN|${DISCORD_WEBHOOK_TOKEN}|g" "$FILE"
else
    echo "File not found"
fi

exec /run.sh
