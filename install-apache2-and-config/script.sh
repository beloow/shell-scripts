#!/bin/bash

# Mettre à jour le système
echo "Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

# Installation de Apache2, Php et ces extensions
echo "Installation de Apache2, Php et ces extensions..."
sudo apt install apache2 php libapache2-mod-php php-mysql wget unzip -y

# Activer et démarrer Apache
echo "Activation et démarrage du service Apache..."
sudo systemctl enable apache2
sudo systemctl start apache2

# Autoriser le trafic HTTP et HTTPS via le pare-feu
echo "Configuration du pare-feu..."
sudo ufw allow 'Apache'

# Vérifier l'état du service Apache
echo "Vérification du statut d'Apache..."
systemctl status apache2 --no-pager

# Créer une page d'accueil personnalisée
create_index_page() {
    local domain="$1"
    local index_file="/var/www/$domain/index.html"
    
    echo "Création de la page d'accueil pour $domain..."
    sudo mkdir -p "/var/www/$domain"
    echo "Success! The $domain virtual host is working!" | sudo tee "$index_file"
    sudo chown -R www-data:www-data "/var/www/$domain"
    sudo chmod -R 755 "/var/www/$domain"
    echo "Page d'accueil créée à $index_file"
}

# Configurer un nouvel hôte virtuel
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

# Demander à l'utilisateur d'entrer un nom de domaine
echo "Veuillez entrer le nom de domaine :"
read your_domain

# Appeler les fonctions
create_index_page "$your_domain"
generate_virtual_host "$your_domain"

echo "Installation terminée ! Vous pouvez accéder à Apache via http://$your_domain/"
