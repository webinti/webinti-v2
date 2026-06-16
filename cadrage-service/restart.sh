#!/usr/bin/env bash
# Réapplique l'unité systemd corrigée et redémarre le service.
set -euo pipefail
BASE=/home/openclaw/projects/webinti/cadrage-service
cp "$BASE/cadrage-quaisud.service" /etc/systemd/system/cadrage-quaisud.service
systemctl daemon-reload
systemctl restart cadrage-quaisud
sleep 1
echo "service: $(systemctl is-active cadrage-quaisud)"
curl -s http://127.0.0.1:3201/api/cadrage/health && echo
