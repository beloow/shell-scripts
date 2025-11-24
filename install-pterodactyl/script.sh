#!/bin/bash

# Script d'installation automatisée de Pterodactyl Panel + Wings sur Ubuntu 20.04

### --- DEMANDES UTILISATEUR --- ###
echo "Entrez le nom de domaine pour accéder au panel (ex: panel.mondomaine.com) :"
read panel_domain


### --- MISE À JOUR DU SYSTÈME --- ###
echo "Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

### --- INSTALLATION DES DÉPENDANCES PANEL --- ###
echo "Installation des dépendances..."
sudo apt install -y software-properties-common curl zip unzip tar ufw
sudo apt install -y php php-cli php-gd php-mysql php-mbstring php-xml php-bcmath php-json php-fpm php-curl
sudo apt install -y mariadb-server nginx

### --- CONFIGURATION MARIADB --- ###
echo "Sécurisation de MariaDB..."
sudo mysql_secure_installation <<EOF
n
y
y
y
y
EOF

echo "Création base de données Pterodactyl..."
sudo mysql -u root -e "CREATE DATABASE panel;"
sudo mysql -u root -e "CREATE USER 'ptero'@'127.0.0.1' IDENTIFIED BY 'password';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'127.0.0.1';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

### --- INSTALLATION DE COMPOSER --- ###
echo "Installation de Composer..."
cd /tmp
curl -sS https://getcomposer.org/installer -o composer-setup.php
php composer-setup.php --install-dir=/usr/local/bin --filename=composer

### --- INSTALLATION PANEL PTERODACTYL --- ###
echo "Installation de Pterodactyl Panel..."
cd /var/www
sudo mkdir pterodactyl
cd pterodactyl
sudo curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
sudo tar -xzvf panel.tar.gz
sudo chmod -R 755 storage/* bootstrap/cache/

sudo composer install --no-dev --optimize-autoloader
sudo cp .env.example .env

sudo php artisan key:generate --force

sudo php artisan p:environment:setup <<EOF
https
$panel_domain
80
n
EOF

sudo php artisan p:environment:database <<EOF
127.0.0.1
3306
panel
ptero
$db_password
EOF

sudo php artisan migrate --seed --force

### --- CRÉATION ADMIN --- ###
echo "Création de l'utilisateur administrateur..."
sudo php artisan p:user:make <<EOF
queva
test@test.com
admin
queva
EOF

sudo chown -R www-data:www-data /var/www/pterodactyl

### --- CONFIGURATION NGINX --- ###
echo "Configuration NGINX..."
sudo tee /etc/nginx/sites-available/pterodactyl.conf <<EOL
server {
    listen 80;
    server_name $panel_domain;
    root /var/www/pterodactyl/public;

    index index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOL

sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

### --- CONFIGURATION UFW --- ###
echo "Configuration du pare-feu..."
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 8080
sudo ufw allow 2022
sudo ufw enable --force

### --- INSTALLATION WINGS --- ###
echo "Installation de Wings..."
curl -sSL https://repo.pterodactyl.io/installers/wings.sh -o /tmp/wings.sh
sudo bash /tmp/wings.sh

### --- INSTALLATION DOCKER --- ###

# Installer Docker si non présent
echo "Installation de Docker..."
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu focal stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker

### --- INSTALLATION DE WINGS --- ### (OFFICIELLE) --- ###

# Création du dossier
sudo mkdir -p /etc/pterodactyl

# Installation des dépendances
sudo apt install -y curl tar unzip

# Télécharger la dernière version de Wings
cd /usr/local/bin
sudo curl -Lo wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"

# Donner les permissions
sudo chmod +x wings

# Créer le service systemd
sudo tee /etc/systemd/system/wings.service > /dev/null << EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now wings

### --- CONFIGURATION WINGS --- ###
# Configuration automatique simplifiée de Wings
# (Ajout du node, allocation et génération du config.yml)
# Génération du script d'auto-configuration Wings
echo "Génération du script wings-autoconfig.sh..."
cat << 'EOF' | sudo tee /root/wings-autoconfig.sh
#!/bin/bash
# Script d'auto-configuration de Wings

echo "Configuration automatique de Wings..."

read -p "URL du panel (ex: https://panel.mondomaine.com): " PANEL_URL
read -p "Clé API node: " API_KEY
read -p "Nom du node: " NODE_NAME
read -p "Adresse publique du node: " NODE_IP
read -p "Port de Wings (par défaut 8080): " WINGS_PORT
WINGS_PORT=\${WINGS_PORT:-8080}

sudo mkdir -p /etc/pterodactyl
sudo tee /etc/pterodactyl/config.yml > /dev/null << EOCFG
# Auto-généré
panel:
  url: "$PANEL_URL"
  token: "$API_KEY"
  node: "$NODE_NAME"

docker:
  container:
    userns_mode: "host"
  network:
    interface: "docker0"
  socket: "/var/run/docker.sock"

allowed_mounts: []
allowed_origins: []

api:
  host: 0.0.0.0
  port: $WINGS_PORT
EOCFG

echo "Configuration générée dans /etc/pterodactyl/config.yml"
echo "Redémarrage de Wings..."
sudo systemctl restart wings
echo "Configuration Wings terminée !"
EOF

# Rendre exécutable
sudo chmod +x /root/wings-autoconfig.sh

echo "Le script d'auto-configuration Wings a été créé : /root/wings-autoconfig.sh"
echo -n "Voulez-vous l'exécuter maintenant ? (o/n) : "
read RUN_WINGS
if [ "$RUN_WINGS" = "o" ] || [ "$RUN_WINGS" = "O" ]; then
    sudo /root/wings-autoconfig.sh
else
    echo "Vous pourrez l'exécuter plus tard avec : sudo /root/wings-autoconfig.sh"
fi

sudo systemctl enable --now wings

### --- FIN --- ###
echo "-----------------------------------------"
echo "Installation terminée !"
echo "Panel disponible à : https://$panel_domain"
