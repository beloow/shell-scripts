#!/bin/bash
set -x

# Mettre à jour le système
echo "Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

# Installer Apache, PHP et les dépendances nécessaires
echo "Installation d'Apache, PHP et des dépendances..."
sudo apt install apache2 php libapache2-mod-php php-mysql wget unzip -y

# Activer et démarrer Apache
echo "Activation et démarrage du service Apache..."
sudo systemctl enable apache2
sudo systemctl start apache2

# Installer MySQL et configurer la base de données
echo "Installation de MySQL..."
sudo apt install mysql-server -y

# Configurer MySQL pour WordPress
echo "Création de la base de données WordPress..."
mysql -e "CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
echo "Création de l'utilisateur WordPress..."
mysql -e "CREATE USER 'wp_user'@'localhost' IDENTIFIED BY 'wp_password';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wp_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Demander à l'utilisateur d'entrer un nom de domaine
echo "Veuillez entrer le nom de domaine :"
read your_domain

# Créer un répertoire pour le domaine et installer WordPress dans ce répertoire
echo "Création du répertoire pour WordPress à /var/www/$your_domain..."
sudo mkdir -p /var/www/$your_domain

# Télécharger et configurer WordPress
echo "Téléchargement de WordPress..."
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xvzf latest.tar.gz
sudo cp -r wordpress/* /var/www/$your_domain/

# Configurer les permissions pour le répertoire WordPress
echo "Configuration des permissions pour WordPress..."
sudo chown -R www-data:www-data /var/www/$your_domain/
sudo chmod -R 755 /var/www/$your_domain/

# Configurer le fichier wp-config.php
echo "Configuration du fichier wp-config.php..."
cd /var/www/$your_domain
sudo mv wp-config-sample.php wp-config.php

# Modifier le fichier wp-config.php pour y ajouter les informations de la base de données
sudo sed -i "s/database_name_here/wordpress/" wp-config.php
sudo sed -i "s/username_here/wp_user/" wp-config.php
sudo sed -i "s/password_here/wp_password/" wp-config.php

# Activer le module Apache pour réécriture d'URL (mod_rewrite)
echo "Activation du module mod_rewrite..."
sudo a2enmod rewrite
sudo systemctl restart apache2

# Autoriser le trafic HTTP et HTTPS via le pare-feu
echo "Configuration du pare-feu..."
sudo ufw allow 'Apache'

# Vérifier l'état du service Apache
echo "Vérification du statut d'Apache..."
systemctl status apache2 --no-pager

# Créer un hôte virtuel pour WordPress
generate_virtual_host() {
    local domain="$1"
    local config_file="/etc/apache2/sites-available/$domain.conf"
    
    echo "Création du fichier de configuration pour l'hôte virtuel $domain..."
    sudo tee "$config_file" <<EOL
<VirtualHost *:80>
    ServerAdmin webmaster@$domain
    ServerName $domain
    DocumentRoot /var/www/$domain
    ErrorLog \${APACHE_LOG_DIR}/$domain.log
    CustomLog \${APACHE_LOG_DIR}/$domain.log combined
</VirtualHost>
EOL
    
    sudo a2dissite 000-default.conf
    sudo a2ensite "$domain.conf"
    
    echo "Vérification de la configuration Apache..."
    sudo apache2ctl configtest
    
    sudo systemctl reload apache2
    echo "Hôte virtuel $domain configuré et activé."
}

# Appel des fonctions
generate_virtual_host "$your_domain"

echo "Installation de WordPress terminée ! Vous pouvez maintenant compléter l'installation via votre navigateur à l'adresse http://$your_domain/"
