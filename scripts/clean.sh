#!/bin/bash

# Arrêter tous les conteneurs
docker compose down

# Supprimer toutes les ressources Docker inutilisées
docker system prune -a --volumes -f