# Platform de supervision réseau et system

## Description

Cette platform permet la supervision des resources system et réseau
à l'aide d'outils open source.

## Technologies utilisées

- Prometheus
- Grafana
- Loki
- Promtail
- Docker

## Lancement

bash
docker compose up -d

## Accès

- Grafana : http://localhost:3000 (login Grafana intégré)
- Prometheus : http://localhost:9090 (protégé par authentification basique via reverse-proxy nginx)
- Loki : http://localhost:3100 (protégé par authentification basique via reverse-proxy nginx)

Identifiants Prometheus/Loki définis dans `nginx/htpasswd`. Pour changer le mot de passe :

bash
openssl passwd -apr1 'nouveau_mot_de_passe'
# remplacer la ligne "admin:..." dans nginx/htpasswd par le résultat
