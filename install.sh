#!/bin/bash

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with bash." >&2
    exit 1
fi

# Pterodactyl Installer Script
#
# Copyright (c) 2025 Gemini
#
# This script is licensed under the MIT License.
#


# --- CONFIGURATION ---
# Set to true to enable debug mode
DEBUG=false

# --- COLORS ---
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# --- UTILITY FUNCTIONS ---
function print_error() {
    echo -e "${RED}Error: $1${RESET}"
}

function print_success() {
    echo -e "${GREEN}Success: $1${RESET}"
}

function print_info() {
    echo -e "${BLUE}Info: $1${RESET}"
}

function print_warning() {
    echo -e "${YELLOW}Warning: $1${RESET}"
}

# --- CHECK ROOT ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Elevating to root..."
   exec sudo "$0" "$@"
fi

# --- OS DETECTION ---
function detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS=CentOS
        VER=$(cat /etc/redhat-release | sed 's/.*release \([0-9\.]\+\).*/\1/')
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    print_info "Detected OS: $OS $VER"
}

function install_with_progress() {
    local packages=$1
    local count=$(echo $packages | wc -w)
    local i=0

    ( 
    for package in $packages; do
        echo "XXX"
        echo "Installing $package..."
        apt-get install -y $package > /dev/null 2>&1
        i=$((i+1))
        echo $((100*i/count))
    done
    ) | whiptail --gauge "Installing dependencies..." 6 70 0
}

# --- DEPENDENCY INSTALLATION ---
function install_dependencies() {
    print_info "Installing dependencies..."
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt-get update
        install_with_progress "whiptail curl software-properties-common apt-transport-https ca-certificates gnupg tar unzip git nginx redis-server php8.2-cli php8.2-fpm php8.2-mysql php8.2-gd php8.2-curl php8.2-zip php8.2-mbstring php8.2-xml php8.2-bcmath"
    elif [ "$OS" == "CentOS" ]; then
        yum install -y newt curl
    else
        print_error "Unsupported OS for dependency installation."
        exit 1
    fi
}

# --- PLACEHOLDER FUNCTIONS ---
function install_panel() {
    print_info "Installing Pterodactyl Panel..."
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        # Add repositories
        add-apt-repository -y ppa:ondrej/php
        apt-get update

        # Install dependencies
        apt-get install -y software-properties-common apt-transport-https ca-certificates curl gnupg tar unzip git nginx redis-server
        apt-get install -y php8.2-cli php8.2-fpm php8.2-mysql php8.2-gd php8.2-curl php8.2-zip php8.2-mbstring php8.2-xml php8.2-bcmath

        # Install Composer
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

    elif [ "$OS" == "CentOS" ]; then
        # Add repositories
        yum install -y epel-release
        rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm
        yum-config-manager --enable remi-php82

        # Install dependencies
        yum install -y curl gnupg tar unzip git nginx redis
        yum install -y php-cli php-fpm php-mysqlnd php-gd php-curl php-zip php-mbstring php-xml php-bcmath

        # Install Composer
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

    else
        print_error "Unsupported OS for Pterodactyl Panel installation."
        exit 1
    fi

    print_success "Dependencies installed successfully."

    # Download and install Pterodactyl Panel
    print_info "Downloading and installing Pterodactyl Panel..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    rm -f panel.tar.gz

    # Set up database
    print_info "Setting up database..."
    DB_PASSWORD=$(whiptail --passwordbox "Enter a password for the database user 'pterodactyl':" 8 78 --title "Database Password" 3>&1 1>&2 2>&3)
    mysql -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';"
    mysql -u root -e "CREATE DATABASE panel;"
    mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
    mysql -u root -e "FLUSH PRIVILEGES;"

    # Configure environment
    print_info "Configuring environment..."
    cp .env.example .env
    composer install --no-dev --optimize-autoloader
    php artisan key:generate --force
    php artisan p:environment:setup --author=admin@example.com --url=http://localhost --timezone=UTC --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
    php artisan migrate --seed --force
    php artisan p:user:make --admin --username=admin --email=admin@example.com --password=admin

    # Set permissions
    print_info "Setting permissions..."
    chown -R www-data:www-data /var/www/pterodactyl/*

    print_success "Pterodactyl Panel installed successfully."

    # Configure webserver
    print_info "Configuring webserver..."
    cat > /etc/nginx/sites-available/pterodactyl.conf << EOL
server {
    listen 80;
    server_name _;

    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_read_timeout 300;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }
}
EOL
    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    rm /etc/nginx/sites-enabled/default
    systemctl restart nginx

    # Configure queue listener
    print_info "Configuring queue listener..."
    cat > /etc/systemd/system/pteroq.service << EOL
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
EOL
    systemctl enable --now pteroq.service

    print_success "Webserver and queue listener configured successfully."
}

function install_wings() {
    print_info "Installing Wings..."
    print_info "Installing Docker and Wings..."

    # Install Docker
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt-get update
        apt-get install -y docker.io
    elif [ "$OS" == "CentOS" ]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
        systemctl start docker
    else
        print_error "Unsupported OS for Docker installation."
        exit 1
    fi
    systemctl enable docker

    # Install Wings
    mkdir -p /etc/pterodactyl
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings

    # Configure Wings
    print_info "Configuring Wings..."
    whiptail --title "Wings Configuration" --msgbox "Please go to your Pterodactyl Panel, create a new node, and copy the configuration to /etc/pterodactyl/config.yml. Press OK when you are done." 10 78

    # Create systemd service
    print_info "Creating systemd service..."
    cat > /etc/systemd/system/wings.service << EOL
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

[Install]
WantedBy=multi-user.target
EOL

    # Enable and start Wings
    systemctl enable --now wings

    print_success "Wings installed and configured successfully."
}

function install_all() {
    install_panel
    install_wings
}

function check_ports() {
    print_info "Checking for required ports..."
    local ports="80 443 8080 2022"
    local in_use=""

    for port in $ports; do
        if ss -tulpn | grep -q ":$port "; then
            in_use="$in_use $port"
        fi
    done

    if [ -n "$in_use" ]; then
        print_warning "The following ports are already in use:$in_use. This may cause issues with the installation."
        if (whiptail --title "Port Warning" --yesno "The following ports are in use:$in_use. Continue anyway?" 10 60); then
            return 0
        else
            exit 1
        fi
    fi
}

# --- MAIN MENU ---
function main_menu() {
    check_ports

    CHOICE=$(whiptail --title "Pterodactyl Installer - Powered by Nayeem Dev, Presented by Feather Flow" --menu "Choose an option:" 15 60 4 \
    "1" "Install Panel and Wings" \
    "2" "Install only Wings" \
    "3" "Install only Panel" \
    "4" "Exit" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1)
            if (whiptail --title "Confirmation" --yesno "This will install the Pterodactyl Panel and Wings. Continue?" 8 78); then
                install_all
            fi
            ;;
        2)
            if (whiptail --title "Confirmation" --yesno "This will install Wings. Continue?" 8 78); then
                install_wings
            fi
            ;;
        3)
            if (whiptail --title "Confirmation" --yesno "This will install the Pterodactyl Panel. Continue?" 8 78); then
                install_panel
            fi
            ;;
        4)
            exit 0
            ;;
    esac

    print_success "Installation complete!"
    print_info "Pterodactyl Panel: http://<your_server_ip>"
    print_info "Default admin user: admin / admin"
    print_info "Wings config: /etc/pterodactyl/config.yml"
    print_info "Pterodactyl Panel files: /var/www/pterodactyl"

}

# --- SCRIPT START ---
whiptail --title "Welcome" --msgbox "Welcome to the Pterodactyl Installer!\n\nPowered by Nayeem Dev, Presented by Feather Flow" 10 60
detect_os
install_dependencies
main_menu
