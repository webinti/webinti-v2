#!/usr/bin/env bash
# Installation du service de cadrage Quai Sud + config nginx.
# À lancer en root :  sudo bash install.sh
set -euo pipefail

BASE=/home/openclaw/projects/webinti/cadrage-service
NGINX_SITE=/etc/nginx/sites-available/webinti.com

echo "→ Installation du service systemd…"
cp "$BASE/cadrage-quaisud.service" /etc/systemd/system/cadrage-quaisud.service
systemctl daemon-reload
systemctl enable --now cadrage-quaisud
echo "  service: $(systemctl is-active cadrage-quaisud)"

echo "→ Mise à jour de la config nginx (sauvegarde dans webinti.com.bak.cadrage)…"
cp "$NGINX_SITE" "${NGINX_SITE}.bak.cadrage"
cp "$BASE/webinti.com.nginx" "$NGINX_SITE"

echo "→ Test de la config nginx…"
if nginx -t; then
  systemctl reload nginx
  echo "  nginx rechargé."
else
  echo "  ERREUR nginx — restauration de l'ancienne config."
  cp "${NGINX_SITE}.bak.cadrage" "$NGINX_SITE"
  exit 1
fi

echo "→ Vérification de l'endpoint…"
sleep 1
curl -s http://127.0.0.1:3201/api/cadrage/health && echo
echo "✓ Terminé. Page : https://webinti.com/cadrage-quaisud/"
