#!/bin/bash
# This script creates self signed certificates for development purposes
# See https://jamielinux.com/docs/openssl-certificate-authority/
# Christian Bargmann <chris@cbrgm.de>
set -e

domain="cbrgm.vnet"
ssl_dir="$HOME/.ssl"
caddy_files_dir="./roles/caddy/files"
root_ca_crt="${ssl_dir}/certs/root-ca.crt"
root_ca_key="${ssl_dir}/private/root-ca.key"

# Create .ssl directory if not exists
if [[ ! -e ${ssl_dir} ]]; then
  echo "\nCreating .ssl directory at ${ssl_dir} ...\n"
  mkdir -p ${ssl_dir}/certs ${ssl_dir}/crl ${ssl_dir}/newcerts ${ssl_dir}/private
  chmod 700 ${ssl_dir}/private
  touch ${ssl_dir}/index.txt
  echo 1000 > ${ssl_dir}/serial
fi

# Create root key if not exists
if [ ! -f ${root_ca_key} ]; then
  echo "\nCreating root CA key ...\n"
  openssl genrsa -out ${root_ca_key} 4096
fi

# Create root certificate if not exists
if [ ! -f ${root_ca_crt} ]; then
  echo "\nCreating root CA certificate ...\n"
  openssl req \
    -subj "/C=DE/ST=Hamburg/L=Hamburg/O=${domain} CA Authority/CN=${domain}" \
    -key ${root_ca_key} \
    -new -x509 -days 7300 -sha256 -extensions v3_ca \
    -out ${root_ca_crt}
  openssl x509 -noout -text -in ${root_ca_crt} | head -n 13
fi

# Ask prompt for yes no
while true; do
  read -p "\nAre you sure you want to generate new self signed certificates?" yn
  case $yn in
    [Yy]* ) break ;;
    [Nn]* ) exit ;;
    * ) echo "Please answer yes or no.\n" ;;
  esac
done

# Create self signed client certificates request
# Generate certificate requests, for main domain and subdomains
openssl req \
  -subj "/C=DE/ST=Hamburg/L=Hamburg/O=${domain}/CN=${domain}" \
  -new -sha256 -nodes \
  -out "${caddy_files_dir}/${domain}.csr" \
  -newkey rsa:2048 \
  -keyout "${caddy_files_dir}/${domain}.key"

openssl req \
  -subj "/C=DE/ST=Hamburg/L=Hamburg/O=${domain}/CN=*.${domain}" \
  -new -sha256 -nodes \
  -out "${caddy_files_dir}/sub.${domain}.csr" \
  -newkey rsa:2048 \
  -keyout "${caddy_files_dir}/sub.${domain}.key"

# Sign certificates using root-ca key and certificate
openssl x509 -req -in "${caddy_files_dir}/${domain}.csr" \
  -CA ${root_ca_crt} \
  -CAkey ${root_ca_key} \
  -CAcreateserial \
  -out "${caddy_files_dir}/${domain}.crt" \
  -days 365 \
  -sha256

openssl x509 -req -in "${caddy_files_dir}/sub.${domain}.csr" \
  -CA ${root_ca_crt} \
  -CAkey ${root_ca_key} \
  -CAcreateserial \
  -out "${caddy_files_dir}/sub.${domain}.crt" \
  -days 365 \
  -sha256

rm "${caddy_files_dir}/sub.${domain}.csr" "${caddy_files_dir}/${domain}.csr"
