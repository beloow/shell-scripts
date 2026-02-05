#!/bin/bash

echo "=== Installation automatique de Pterodactyl Panel ==="

# Sécurité
if [ "$EUID" -ne 0 ]; then
  echo "❌ Lance ce script en root"
  exit
fi

# Variables (À MODIFIER)
PANEL_DOMAIN="http://TON_IP_OU_DOMAINE"
DB_PASSWORD="MotDePasseUltraFort"
ADMIN_EMAIL="admin@example.com"
TIMEZONE="Europe/Paris"

echo "🔄 Mise à jour du système"
apt update && apt upgrade -y

echo "📦 Installation des dépendances"
apt install -y software-properties-common curl apt-transport-https ca-certificates gnupg unzip

add-apt-repository -y ppa:ondrej/php
apt update

apt install -y \
php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} \
nginx mariadb-server redis-server

echo "📦 Installation de Composer"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo "🐳 Installation de Docker"
curl -sSL https://get.docker.com | bash
systemctl enable --now docker

echo "🗄️ Configuration MariaDB"
mysql -u root <<EOF
CREATE DATABASE panel;
CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

echo "📁 Installation du panel"
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz

chmod -R 755 storage bootstrap/cache
cp .env.example .env

composer install --no-dev --optimize-autoloader
php artisan key:generate --force

echo "⚙️ Configuration du panel"
php artisan p:environment:setup --author="$ADMIN_EMAIL" --url="$PANEL_DOMAIN" --timezone="$TIMEZONE" --cache=file --session=file --queue=database --disable-telemetry

php artisan p:environment:database \
--host=127.0.0.1 \
--port=3306 \
--database=panel \
--username=pterodactyl \
--password="$DB_PASSWORD"

php artisan migrate --seed --force

echo "👤 Création utilisateur admin"
php artisan p:user:make --email="$ADMIN_EMAIL" --username=admin --name-first=Admin --name-last=Panel --password=Admin123!

chown -R www-data:www-data /var/www/pterodactyl

echo "⏱️ Configuration cron"
echo "* * * * * www-data php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" > /etc/cron.d/pterodactyl

echo "⚙️ Service queue worker"
cat <<SERVICE >/etc/systemd/system/pteroq.service
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now pteroq.service

echo "🐉 Installation de Wings"
mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod +x /usr/local/bin/wings

echo "✅ Installation terminée"
echo "➡️ Accède au panel : $PANEL_DOMAIN"
echo "➡️ Crée une node dans le panel pour finaliser Wings"
