# Platform de supervision réseau et système

## Description

Cette plateforme permet la supervision des ressources système et réseau
à l'aide d'outils open source, ainsi que la détection d'incidents de sécurité via Wazuh.

## Technologies utilisées

- Prometheus
- Grafana
- Loki
- Promtail
- Wazuh (manager, indexer, dashboard)
- Docker / Docker Compose

## Configuration initiale

Avant le premier lancement, copier les fichiers d'exemple et renseigner des identifiants :

```bash
cp .env.example .env
cp wazuh/.env.example wazuh/.env
```

Les fichiers `.env` (racine et `wazuh/`) sont ignorés par Git : ils contiennent les mots de passe
réels et ne doivent jamais être commités.

## Lancement

### Stack principale (Prometheus / Grafana / Loki)

```bash
./scripts/start.sh
# ou directement : docker compose up -d
```

### Module Wazuh (sécurité)

```bash
./scripts/startwazuh.sh
# ou directement : cd wazuh && docker compose up -d
```

Le module Wazuh nécessite des certificats TLS générés une seule fois (déjà fournis dans
`wazuh/config/wazuh_indexer_ssl_certs/`, non commités). Pour les régénérer (ex. après un `docker
compose down -v` qui supprime les volumes) :

```bash
cd wazuh
docker compose -f generate-indexer-certs.yml run --rm generator
docker network rm wazuh_default
```

## Accès

| Application | URL | Identifiant |
|---|---|---|
| Grafana | http://localhost:3000 | `admin` / mot de passe défini dans `.env` |
| Prometheus (via Nginx) | http://localhost:9090 | `admin` / mot de passe défini dans `nginx/htpasswd` |
| Loki (via Nginx) | http://localhost:3100 | `admin` / mot de passe défini dans `nginx/htpasswd` |
| Wazuh Dashboard | https://localhost:5601 | `admin` / mot de passe défini dans `wazuh/.env` |
| Wazuh Manager API | https://localhost:55001 | `wazuh-wui` / mot de passe défini dans `wazuh/.env` |

Le certificat du dashboard Wazuh est auto-signé : un avertissement du navigateur est normal.
Le port hôte du Manager API est `55001` (et non `55000`) uniquement si un autre conteneur
utilise déjà `55000` sur la machine ; à l'intérieur du réseau Docker, le dashboard continue de
joindre le manager via `wazuh.manager:55000`, donc ce remap n'affecte que l'accès direct depuis
l'hôte.

### Ordre de démarrage recommandé pour Wazuh

Au premier lancement, démarrer l'indexer seul et attendre qu'il réponde avant le manager/dashboard
(le plugin de sécurité OpenSearch met 30-60s à s'initialiser) :

```bash
cd wazuh
docker compose up -d wazuh.indexer
# attendre que https://localhost:9200 réponde (curl -k -u admin:<mdp> https://localhost:9200)
docker compose up -d wazuh.manager wazuh.dashboard
```

Aux démarrages suivants, `docker compose up -d` (ou `./scripts/startwazuh.sh`) suffit : les données
sont déjà indexées et l'ordre est moins critique.

### Changer les mots de passe

- **Grafana** : modifier `GRAFANA_ADMIN_PASSWORD` dans `.env`, puis
  `docker compose exec grafana grafana cli admin reset-admin-password 'nouveau_mot_de_passe'`
  (la variable d'environnement seule ne s'applique qu'à la création initiale de la base Grafana).
- **Prometheus / Loki (Nginx)** :
  ```bash
  openssl passwd -apr1 'nouveau_mot_de_passe'
  # remplacer la ligne "admin:..." dans nginx/htpasswd par le résultat
  ```
- **Wazuh** : modifier `INDEXER_PASSWORD` dans `wazuh/.env`, régénérer le hash bcrypt et le
  placer dans `wazuh/config/wazuh_indexer/internal_users.yml` (utilisateur `admin`) :
  ```bash
  python -c "import bcrypt; print(bcrypt.hashpw(b'nouveau_mot_de_passe', bcrypt.gensalt(rounds=12)).decode())"
  ```
  Mettre aussi à jour `API_PASSWORD` dans `wazuh/.env` et le mot de passe dans
  `wazuh/config/wazuh_dashboard/wazuh.yml`, puis redémarrer la stack Wazuh.

## Limite connue (environnement Windows)

`node-exporter` et `promtail` s'exécutent à l'intérieur de la VM Linux gérée par Docker Desktop.
Sur un hôte Windows, ils supervisent donc les métriques/logs de cette VM interne, pas nativement
ceux de Windows. Pour une supervision native de l'hôte Windows, un exporter dédié (ex.
`windows_exporter`) serait nécessaire en dehors de Docker.
