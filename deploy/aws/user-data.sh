#!/bin/bash
# User data da EC2 (Amazon Linux 2023). Preencha DB_PASSWORD abaixo antes de colar no console.
exec > /var/log/eventos-deploy.log 2>&1
set -x
DB_URL='jdbc:postgresql://aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require'
DB_USER='postgres.mirmpnbpbdvwixqxyptm'
DB_PASSWORD='COLE_AQUI_A_SENHA_DO_SUPABASE'
KC_ADMIN_PASSWORD='COLE_AQUI_UMA_SENHA_PARA_O_ADMIN_DO_KEYCLOAK'

# swap para o build (instancia pequena)
dd if=/dev/zero of=/swapfile bs=1M count=2048 && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
dnf install -y docker git
systemctl enable --now docker
mkdir -p /usr/local/lib/docker/cli-plugins
curl -sSL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

git clone https://github.com/gustavofrainer21/Sistema-de-Gestao-de-Eventos-e-Auditorios /opt/eventos
cd /opt/eventos/deploy/aws

# descobre o endereco do API Gateway HTTP (API com nome "eventos")
export AWS_DEFAULT_REGION=us-east-1
for i in $(seq 1 120); do
  PUBLIC_HOST=$(aws apigatewayv2 get-apis --query "Items[?Name=='eventos'].ApiEndpoint | [0]" --output text 2>/dev/null | sed 's#https://##')
  [ -n "$PUBLIC_HOST" ] && [ "$PUBLIC_HOST" != "None" ] && break
  sleep 15
done
cat > .env <<ENV
PUBLIC_HOST=$PUBLIC_HOST
DB_URL=$DB_URL
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
KC_ADMIN_PASSWORD=$KC_ADMIN_PASSWORD
ENV
docker compose up -d --build
