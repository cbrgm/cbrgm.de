#!/bin/bash
# Backups all files and sql data for ansible roles
set -euo pipefail

# Parameters
timestamp=${1:-''}
selection=${2:-''}

# Set timestamp if null
if [[ -z ${timestamp} ]]; then
  timestamp=`date +%Y-%m-%d`
fi

# global vars
domain="cbrgm.vnet"
ssh_port=22
backup_dir="./backup/${timestamp}"

# Create directory if not exists
[[ ! -e ${backup_dir} ]] && mkdir -p ${backup_dir}

function backup_postgres {
  local database="$1"
  local postgres_backup="${backup_dir}/${database}-postgres-${timestamp}.gz"
  echo "Backup ${backup_dir}/${database}-postgres-${timestamp}.gz"
  ssh -p ${ssh_port} ${domain} "pg_dump --user=chris ${database} --format=custom" | gzip -9c > ${postgres_backup}
}

# Backup all gitea files
function backup_gitea {
  local gitea_backup="${backup_dir}/gitea-backup-${timestamp}.tar.gz"
  echo "Backup gitea data in ${gitea_backup} ..."
  ssh -p ${ssh_port} ${domain} "sudo systemctl stop gitea"
  ssh -p ${ssh_port} ${domain} "sudo tar -C /home/git -cf - gitea" | gzip -9c > ${gitea_backup}
  backup_postgres gitea
  ssh -p ${ssh_port} ${domain} "sudo systemctl start gitea"
}

# Backup all caddy webserver files
function backup_caddy {
  local caddy_backup="${backup_dir}/caddy-backup-${timestamp}.tar.gz"
  echo "Backup Caddy webserver in ${caddy_backup} ..."
  ssh -p ${ssh_port} ${domain} "sudo systemctl stop caddy"
  ssh -p ${ssh_port} ${domain} "sudo tar -C /home/caddy -cf - certs data" | gzip -9c > ${caddy_backup}
  ssh -p ${ssh_port} ${domain} "sudo systemctl start caddy"
}

# Backup all dockerhub files
function backup_docker {
  local docker_backup="${backup_dir}/docker_backup-${timestamp}.tar.gz"
  echo "Backup dockerhub files in ${docker_backup} ..."
  ssh -p ${ssh_port} ${domain} "sudo docker-compose -f /home/dockerhub/registry/docker-compose.yml down"
  ssh -p ${ssh_port} ${domain} "sudo tar -C /home/dockerhub -cf - registry" | gzip -9c > ${docker_backup}
  ssh -p ${ssh_port} ${domain} "sudo docker-compose -f /home/dockerhub/registry/docker-compose.yml up -d"
}

function backup_drone {
  local drone_backup="${backup_dir}/drone-backup-${timestamp}.tar.gz"
  echo "Backup drone data in ${drone_backup} ..."
  ssh -p ${ssh_port} ${domain} "sudo docker-compose -f /home/drone/drone/docker/docker-compose.yml down"
  ssh -p ${ssh_port} ${domain} "sudo tar -C /home/drone -cf - drone" | gzip -9c > ${drone_backup}
  backup_postgres droneio
  ssh -p ${ssh_port} ${domain} "sudo docker-compose -f /home/drone/drone/docker/docker-compose.yml up -d"
}

case "${selection}" in
  "caddy")
    backup_caddy
    ;;
  "gitea")
    backup_gitea
    ;;
  "drone")
    backup_drone
    ;;
  "docker")
    backup_docker
    ;;
  ""|"all")
    backup_caddy
    backup_gitea
    backup_drone
    backup_docker
    ;;
esac
