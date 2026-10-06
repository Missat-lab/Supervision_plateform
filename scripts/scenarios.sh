#!/bin/bash
# Scenarios d'evaluation de la plateforme (Annexe G du rapport).
# Adaptes a un hote Windows + Docker Desktop : les scenarios necessitant
# normalement des outils Linux natifs (stress-ng, logger, iptables) sont
# rejoues via des conteneurs jetables sur le reseau "monitoring", ce qui
# reste mesurable par node-exporter/cAdvisor/Blackbox car ils tournent
# dans la meme VM Linux geree par Docker Desktop.
#
# Usage : ./scripts/scenarios.sh sc1 | sc2 | sc3 | sc4 | sc5 | sc6 | all
#
# Pour chaque scenario, noter l'horodatage affiche puis relever dans Grafana
# (menu Alerting > History) l'instant de passage a l'etat Firing (MTTD) et
# de retour a Normal (MTTR), comme decrit au point 3.8.2 et a l'Annexe G.

set -e
NET="supervision-platform_monitoring"

sc1_cpu() {
  echo "SC1 - Charge processeur elevee : injection a $(date +%T)"
  docker run --rm --name stress-cpu --network "$NET" polinux/stress \
    stress --cpu 4 --timeout 300s
  echo "SC1 - Fin de charge a $(date +%T)"
}

sc2_memoire() {
  echo "SC2 - Saturation memoire simulee : injection a $(date +%T)"
  docker run --rm --name stress-mem --network "$NET" polinux/stress \
    stress --vm 2 --vm-bytes 512M --timeout 180s
  echo "SC2 - Fin de charge a $(date +%T)"
}

sc3_arret_service() {
  echo "SC3 - Arret volontaire d'un service (loki) a $(date +%T)"
  docker compose stop loki
  echo "Service arrete. Attente de 120s avant redemarrage..."
  sleep 120
  docker compose start loki
  echo "SC3 - Service redemarre a $(date +%T)"
}

sc4_logs() {
  echo "SC4 - Generation massive de journaux : debut a $(date +%T)"
  docker run -d --name log-generator --network "$NET" alpine \
    sh -c 'i=1; while [ $i -le 500 ]; do echo "TEST simulation journal $i"; i=$((i+1)); sleep 0.05; done'
  sleep 30
  docker rm -f log-generator >/dev/null 2>&1 || true
  echo "SC4 - Fin de generation a $(date +%T)"
}

sc5_coupure_reseau() {
  echo "SC5 - Coupure d'une liaison reseau (isolement de blackbox-exporter) a $(date +%T)"
  docker network disconnect "$NET" blackbox-exporter
  echo "Liaison coupee. Attente de 120s avant retablissement..."
  sleep 120
  docker network connect "$NET" blackbox-exporter
  echo "SC5 - Liaison retablie a $(date +%T)"
}

sc6_auth_echouees() {
  echo "SC6 - Tentatives d'authentification echouees a $(date +%T)"
  echo "Necessite un serveur SSH accessible (agent Wazuh installe sur l'hote surveille)."
  for i in $(seq 1 10); do
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
      utilisateur_inexistant@localhost true 2>/dev/null || true
  done
  echo "SC6 - Fin des tentatives a $(date +%T)"
}

case "$1" in
  sc1) sc1_cpu ;;
  sc2) sc2_memoire ;;
  sc3) sc3_arret_service ;;
  sc4) sc4_logs ;;
  sc5) sc5_coupure_reseau ;;
  sc6) sc6_auth_echouees ;;
  all)
    sc1_cpu; sc2_memoire; sc3_arret_service; sc4_logs; sc5_coupure_reseau; sc6_auth_echouees
    ;;
  *)
    echo "Usage: $0 {sc1|sc2|sc3|sc4|sc5|sc6|all}"
    exit 1
    ;;
esac
