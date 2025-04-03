#!/bin/bash

# Mettre à jour le système
echo "Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

# Installer Apache
echo "Installation d'Apache..."
sudo apt install apache2 -y

# Activer et démarrer Apache
echo "Activation et démarrage du service Apache..."
sudo systemctl enable apache2
sudo systemctl start apache2

# Autoriser le trafic HTTP et HTTPS via le pare-feu
echo "Configuration du pare-feu..."
sudo ufw allow 'Apache'
sudo ufw enable

# Vérifier l'état du service Apache
echo "Vérification du statut d'Apache..."
systemctl status apache2 --no-pager

# Créer une page d'accueil personnalisée
create_index_page() {
    local domain="$1"
    local index_file="/var/www/$domain/index.html"
    
    echo "Création de la page d'accueil pour $domain..."
    sudo mkdir -p "/var/www/$domain"
    echo "Success! The $domain virtual host is working!" | sudo tee "$index_file" > /dev/null
    sudo chown -R www-data:www-data "/var/www/$domain"
    sudo chmod -R 755 "/var/www/$domain"
    echo "Page d'accueil créée à $index_file"
}

# Demander à l'utilisateur d'entrer un nom de domaine
echo "Veuillez entrer le nom de domaine :"
read your_domain
create_index_page "$your_domain"
generate_virtual_host "$your_domain"

# Configurer un nouvel hôte virtuel
generate_virtual_host() {
    local domain="$1"
    local config_file="/etc/apache2/sites-available/$domain.conf"
    
    echo "Création du fichier de configuration pour l'hôte virtuel $domain..."
    sudo tee "$config_file" > /dev/null <<EOL
<VirtualHost *:80>
    ServerAdmin webmaster@$domain
    ServerName $domain
    DocumentRoot /var/www/$domain
    ErrorLog \${APACHE_LOG_DIR}/$domain_error.log
    CustomLog \${APACHE_LOG_DIR}/$domain_access.log combined
</VirtualHost>
EOL
    
    sudo a2dissite 000-default.conf
    sudo a2ensite "$domain.conf"
    
    echo "Vérification de la configuration Apache..."
    sudo apache2ctl configtest
    
    sudo systemctl reload apache2
    echo "Hôte virtuel $domain configuré et activé."
}

echo "Installation terminée ! Vous pouvez accéder à Apache via http://$your_domain/"
