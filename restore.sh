#!/bin/bash
# Backups all files and sql data for ansible roles
set -euo pipefail

# Parameters
timestamp=${1:-''}
selection=${2:-''}

# global vars
domain="cbrgm.vnet"
ssh_port=22
backup_dir="./backup/${timestamp}"

function restore_postgres {
  local database="$1"
  local postgres_backup="${backup_dir}/${database}-postgres-${timestamp}.gz"
  echo "Restore ${backup_dir}/${database}-postgres-${timestamp}.gz ..."
  cat ${postgres_backup} | gunzip -c - | ssh -p ${ssh_port} ${domain} "pg_restore --user=chris --dbname=${database} --clean"
}

# Backup all gitea files
function restore_gitea {
  local gitea_backup="${backup_dir}/gitea-backup-${timestamp}.tar.gz"
  echo "Restore gitea from ${gitea_backup} ..."
  ssh -p ${ssh_port} ${domain} "sudo systemctl stop gitea"
  cat ${gitea_backup} | ssh -p ${ssh_port} ${domain} "sudo tar -C /home/git -xzvf -"
  restore_postgres gitea
  ssh -p ${ssh_port} ${domain} "sudo systemctl start gitea"
}

# Restore all caddyserver files
function restore_caddy {
  local caddy_backup="${backup_dir}/caddy-backup-${timestamp}.tar.gz"
  echo "Restore caddyserver from ${caddy_backup} ..."
  ssh -p ${ssh_port} ${domain} "sudo systemctl stop caddy"
  cat ${caddy_backup} | ssh -p ${ssh_port} ${domain} "sudo tar -C /home/caddy -xzvf -"
  ssh -p ${ssh_port} ${domain} "sudo systemctl start caddy"
}

function restore_docker {
  local docker_backup="${backup_dir}/docker_backup-${timestamp}.tar.gz"
  echo "Restore docker data from ${docker_backup} ..."
  ssh -p ${ssh_port} ${domain} "sudo docker-compose -f /home/dockerhub/registry/docker-compose.yml down"
  cat ${docker_backup} | ssh -p ${ssh_port} ${domain} "sudo tar -C /home/dockerhub -xzvf -"
  ssh -p ${ssh_port} ${domain} "sudo docker-compose -f /home/dockerhub/registry/docker-compose.yml up -d"
}

# Restore all droneio data
# Restoring includes drone users /home/ directory and database dump
function restore_drone {
  local drone_backup="${backup_dir}/drone-backup-${timestamp}.tar.gz"
  echo "Restore drone data from ${drone_backup} ..."
  ssh -p ${ssh_port} ${domain} "sudo docker-compose -f /home/drone/drone/docker/docker-compose.yml down"
  cat ${drone_backup} | ssh -p ${ssh_port} ${domain} "sudo tar -C /home/drone -xzvf -"
  restore_postgres droneio
  ssh -p ${ssh_port} ${domain} "sudo docker-compose -f /home/drone/drone/docker/docker-compose.yml up -d"
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
  "docker")
    restore_docker
    ;;
  ""|"all")
    restore_caddy
    restore_gitea
    restore_drone
    restore_docker
    ;;
esac
