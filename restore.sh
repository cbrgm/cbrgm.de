#!/bin/bash
# Backups all files and sql data for ansible roles
set -euo pipefail

# Parameters
timestamp=${1:-''}
selection=${2:-''}

# global vars
domain="cbrgm.vnet"
backup_dir="./backup/${timestamp}"

function restore_postgres {
  local database="$1"
  local postgres_backup="${backup_dir}/${database}-postgres-${timestamp}.gz"
  echo "Restore ${backup_dir}/${database}-postgres-${timestamp}.gz ..."
  cat ${postgres_backup} | gunzip -c - | ssh ${domain} "pg_restore --user=chris --dbname=${database} --clean"
}

# Backup all gitea files
function restore_gitea {
  local gitea_backup="${backup_dir}/gitea-backup-${timestamp}.tar.gz"
  echo "Restore gitea from ${gitea_backup} ..."
  ssh ${domain} "sudo systemctl stop gitea"
  cat ${gitea_backup} | ssh ${domain} "sudo tar -C /home/git -xzvf -"
  restore_postgres gitea
  ssh ${domain} "sudo systemctl start gitea"
}

# Restore all caddyserver files
function restore_caddy {
  local caddy_backup="${backup_dir}/caddy-backup-${timestamp}.tar.gz"
  echo "Restore caddyserver from ${caddy_backup} ..."
  ssh ${domain} "sudo systemctl stop caddy"
  cat ${caddy_backup} | ssh ${domain} "sudo tar -C /home/caddy -xzvf -"
  ssh ${domain} "sudo systemctl start caddy"
}

# Restore all droneio data
# Restoring includes drone users /home/ directory and database dump
function restore_drone {
  local drone_backup="${backup_dir}/drone-backup-${timestamp}.tar.gz"
  echo "Restore drone data from ${drone_backup} ..."
  ssh ${domain} "sudo docker-compose -f /home/drone/drone/docker/docker-compose.yml down"
  cat ${drone_backup} | ssh ${domain} "sudo tar -C /home/drone -xzvf -"
  restore_postgres droneio
  ssh ${domain} "sudo docker-compose -f /home/drone/drone/docker/docker-compose.yml up -d"
}

case "${selection}" in
  "caddy")
    restore_caddy
    ;;
  "gitea")
    restore_gitea
    ;;
  "drone")
    restore_drone
    ;;
  ""|"all")
    restore_caddy
    restore_gitea
    restore_drone
    ;;
esac
