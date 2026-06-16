# Geo-block — bloquer le VPS pour certains pays

Rend **tous les sites du VPS inaccessibles** (ports 80/443 uniquement) depuis une
liste de pays, via `ipset` + `iptables`/`ip6tables`. SSH (port 22) et tout autre
port ne sont **jamais** touchés.

- **Pays bloqués** (24) : Ligue arabe (Maroc, Algérie, Tunisie, Libye, Mauritanie,
  Égypte, Soudan, Somalie, Djibouti, Comores, Arabie Saoudite, Émirats, Qatar,
  Koweït, Bahreïn, Oman, Yémen, Irak, Syrie, Liban, Jordanie, Palestine) **+ Iran + Turquie**.
  Pour modifier : éditer la variable `COUNTRIES` dans `geoblock.sh`.
- **Source des plages IP** : [ipdeny.com](https://www.ipdeny.com) (listes agrégées), IPv4 + IPv6.
- **Effet** : les visiteurs de ces pays voient la connexion échouer (paquets *DROP*).

## Installation (à lancer en root sur le VPS)

```sh
cd /home/openclaw/projects/webinti

# 1. Installer le script
sudo install -m 755 deploy/geoblock/geoblock.sh /usr/local/sbin/geoblock.sh

# 2. Construire les sets + activer le blocage maintenant
sudo /usr/local/sbin/geoblock.sh refresh

# 3. Persistance : ré-appliquer au boot + rafraîchir chaque mois
sudo cp deploy/geoblock/geoblock.service \
        deploy/geoblock/geoblock-refresh.service \
        deploy/geoblock/geoblock-refresh.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now geoblock.service        # restaure au démarrage
sudo systemctl enable --now geoblock-refresh.timer  # maj mensuelle des IP
```

## Vérifier

```sh
sudo /usr/local/sbin/geoblock.sh status
```

## Désactiver / rollback complet

```sh
sudo /usr/local/sbin/geoblock.sh remove
sudo systemctl disable --now geoblock.service geoblock-refresh.timer
```

## Notes

- Le blocage est au niveau **IP**, donc il s'applique à **tous les domaines** du VPS
  (webinti.com, macrodiet.app, trackhour.fr, etc.). Pour ne bloquer qu'un seul
  domaine, il faudrait passer par nginx + GeoIP2 (autre méthode).
- Le géo-IP n'est jamais parfait : VPN/proxy contournent le blocage, et de rares IP
  peuvent être mal classées. La liste est rafraîchie tous les mois.
- `apply` (boot) restaure les sets depuis `/etc/geoblock/ipset.conf` sans réseau ;
  `refresh` (mensuel) retélécharge les plages à jour.
