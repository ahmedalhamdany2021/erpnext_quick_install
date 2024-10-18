#!/usr/bin/env bash

# Setting error handler
handle_error() {
    local line=$1
    local exit_code=$?
    echo "An error occurred on line $line with exit status $exit_code"
    exit $exit_code
}

install_hrms() {
    bench get-app hrms --branch version-15 && \
    bench --site $site_name install-app hrms
}

uninstall_remove_hrms() {
    bench --site $site_name uninstall-app hrms
    bench remove-app hrms
}

install_whitelabel_terp() {
    bench get-app https://github.com/AlastairDare/whitelabel-terp --branch terp && \
    bench --site $site_name install-app whitelabel
}

trap 'handle_error $LINENO' ERR
set -e

# Retrieve server IP
server_ip=$(hostname -I | awk '{print $1}')

# Setting up colors for echo commands
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Checking Supported OS and distribution
SUPPORTED_DISTRIBUTIONS=("Ubuntu" "Debian")
SUPPORTED_VERSIONS=("24.04" "23.04" "22.04" "20.04" "12" "11" "10" "9" "8")

check_os() {
    local os_name=$(lsb_release -is)
    local os_version=$(lsb_release -rs)
    local os_supported=false
    local version_supported=false

    for i in "${SUPPORTED_DISTRIBUTIONS[@]}"; do
        if [[ "$i" = "$os_name" ]]; then
            os_supported=true
            break
        fi
    done

    for i in "${SUPPORTED_VERSIONS[@]}"; do
        if [[ "$i" = "$os_version" ]]; then
            version_supported=true
            break
        fi
    done

    if [[ "$os_supported" = false ]] || [[ "$version_supported" = false ]]; then
        echo -e "${RED}This script is not compatible with your operating system or its version.${NC}"
        exit 1
    fi
}

check_os

# Detect the platform (similar to $OSTYPE)
OS="`uname`"
case $OS in
  'Linux')
    OS='Linux'
    if [ -f /etc/redhat-release ] ; then
      DISTRO='CentOS'
    elif [ -f /etc/debian_version ] ; then
      if [ "$(lsb_release -si)" == "Ubuntu" ]; then
        DISTRO='Ubuntu'
      else
        DISTRO='Debian'
      fi
    fi
    ;;
  *) ;;
esac

ask_twice() {
    local prompt="$1"
    local secret="$2"
    local val1 val2

    while true; do
        if [ "$secret" = "true" ]; then
            read -rsp "$prompt: " val1
            echo >&2
        else
            read -rp "$prompt: " val1
            echo >&2
        fi

        if [ "$secret" = "true" ]; then
            read -rsp "Confirm password: " val2
            echo >&2
        else
            read -rp "Confirm password: " val2
            echo >&2
        fi

        if [ "$val1" = "$val2" ]; then
            printf "${GREEN}Password confirmed${NC}" >&2
            echo "$val1"
            break
        else
            printf "${RED}Inputs do not match. Please try again${NC}\n" >&2
            echo -e "\n"
        fi
    done
}
echo -e "${LIGHT_BLUE}Welcome to the T-ERP ERPNext Installer...${NC}"
echo -e "\n"
sleep 3

# Set the bench version directly to version 15
bench_version="version-15"
version_choice="Version 15"

# Proceed with the installation without user confirmation
echo -e "${GREEN}$version_choice is selected for installation by default.${NC}"
echo -e "${GREEN}Proceeding with installation of $version_choice...${NC}"

# Small pause for readability
sleep 2

# Simplified check for Ubuntu 24.04 and Version 15
if [[ "$(lsb_release -si)" == "Ubuntu" && "$(lsb_release -rs)" == "24.04" ]]; then
    echo -e "${GREEN}Ubuntu 24.04 detected. Proceeding with Version 15 installation.${NC}"
else
    echo -e "${RED}This script is intended for Ubuntu 24.04 only. Exiting.${NC}"
    exit 1
fi

# Check OS and version compatibility for all versions
check_os

# First Let's take you home
cd $(sudo -u $USER echo $HOME)

# Next let's set some important parameters.
# We will need your required SQL root passwords
echo -e "${YELLOW}Now let's set some important parameters...${NC}"
sleep 1
echo -e "${YELLOW}We will need your required SQL root password${NC}"
sleep 1
sqlpasswrd=$(ask_twice "What is your required SQL root password" "true")
sleep 1
echo -e "\n"

# Now let's make sure your instance has the most updated packages
echo -e "${YELLOW}Updating system packages...${NC}"
sleep 2
sudo apt update
sudo apt upgrade -y
echo -e "${GREEN}System packages updated.${NC}"
sleep 2

# Now let's install a couple of requirements: git, curl and pip
echo -e "${YELLOW}Installing preliminary package requirements${NC}"
sleep 3
sudo apt install software-properties-common git curl -y

# Next we'll install the python environment manager...
echo -e "${YELLOW}Installing python environment manager and other requirements...${NC}"
sleep 2

# Install Python 3.10 if not already installed or version is less than 3.10
py_version=$(python3 --version 2>&1 | awk '{print $2}')
py_major=$(echo "$py_version" | cut -d '.' -f 1)
py_minor=$(echo "$py_version" | cut -d '.' -f 2)

if [ -z "$py_version" ] || [ "$py_major" -lt 3 ] || [ "$py_major" -eq 3 -a "$py_minor" -lt 10 ]; then
    echo -e "${LIGHT_BLUE}It appears this instance does not meet the minimum Python version required for ERPNext 14 (Python3.10)...${NC}"
    sleep 2 
    echo -e "${YELLOW}Not to worry, we will sort it out for you${NC}"
    sleep 4
    echo -e "${YELLOW}Installing Python 3.10+...${NC}"
    sleep 2

    sudo apt -qq install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev -y && \
    wget https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz && \
    tar -xf Python-3.10.11.tgz && \
    cd Python-3.10.11 && \
    ./configure --prefix=/usr/local --enable-optimizations --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib" && \
    make -j $(nproc) && \
    sudo make altinstall && \
    cd .. && \
    sudo rm -rf Python-3.10.11 && \
    sudo rm Python-3.10.11.tgz && \
    pip3.10 install --user --upgrade pip && \
    echo -e "${GREEN}Python3.10 installation successful!${NC}"
    sleep 2
fi
echo -e "\n"
echo -e "${YELLOW}Installing additional Python packages and Redis Server${NC}"
sleep 2
sudo apt install git python3-dev python3-setuptools python3-venv python3-pip redis-server -y && \

# Detect the architecture
arch=$(uname -m)
case $arch in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) echo -e "${RED}Unsupported architecture: $arch${NC}"; exit 1 ;;
esac

sudo apt install fontconfig libxrender1 xfonts-75dpi xfonts-base -y
# Download and install wkhtmltox for the detected architecture
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_$arch.deb && \
sudo dpkg -i wkhtmltox_0.12.6.1-2.jammy_$arch.deb || true && \
sudo cp /usr/local/bin/wkhtmlto* /usr/bin/ && \
sudo chmod a+x /usr/bin/wk* && \
sudo rm wkhtmltox_0.12.6.1-2.jammy_$arch.deb && \
sudo apt --fix-broken install -y && \
sudo apt install fontconfig xvfb libfontconfig xfonts-base xfonts-75dpi libxrender1 -y && \

echo -e "${GREEN}Done!${NC}"
sleep 1
echo -e "\n"
#... And mariadb with some extra needed applications.
echo -e "${YELLOW}Now installing MariaDB and other necessary packages...${NC}"
sleep 2
sudo apt install mariadb-server mariadb-client -y
echo -e "${GREEN}MariaDB and other packages have been installed successfully.${NC}"
sleep 2

# Use a hidden marker file to determine if this section of the script has run before.
MARKER_FILE=~/.mysql_configured.marker

if [ ! -f "$MARKER_FILE" ]; then
    # Now we'll go through the required settings of the mysql_secure_installation...
    echo -e ${YELLOW}"Now we'll go ahead to apply MariaDB security settings...${NC}"
    sleep 2

    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';"
    sudo mysql -u root -p"$sqlpasswrd" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';"
    sudo mysql -u root -p"$sqlpasswrd" -e "DELETE FROM mysql.user WHERE User='';"
    sudo mysql -u root -p"$sqlpasswrd" -e "DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    sudo mysql -u root -p"$sqlpasswrd" -e "FLUSH PRIVILEGES;"

    echo -e "${YELLOW}...And add some settings to /etc/mysql/my.cnf:${NC}"
    sleep 2

    sudo bash -c 'cat << EOF >> /etc/mysql/my.cnf
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF'

    sudo service mysql restart

    # Create the hidden marker file to indicate this section of the script has run.
    touch "$MARKER_FILE"
    echo -e "${GREEN}MariaDB settings done!${NC}"
    echo -e "\n"
    sleep 1
fi

# Install NVM, Node, npm and yarn
echo -e ${YELLOW}"Now to install NVM, Node, npm and yarn${NC}"
sleep 2
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash

# Add environment variables to .profile
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.profile
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.profile
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> ~/.profile

# Source .profile to load the new environment variables in the current session
source ~/.profile

# Installing node/nvm for Version-15 with no choice or option for another version
nvm install 18
node_version="18"


sudo apt-get -qq install npm -y
sudo npm install -g yarn
echo -e "${GREEN}Package installation complete!${NC}"
sleep 2

# Now let's reactivate virtual environment
if [ -z "$py_version" ] || [ "$py_major" -lt 3 ] || [ "$py_major" -eq 3 -a "$py_minor" -lt 10 ]; then
    python3.10 -m venv $USER && \
    source $USER/bin/activate
    nvm use $node_version
fi

# Install bench
echo -e "${YELLOW}Now let's install bench${NC}"
sleep 2

# Check if EXTERNALLY-MANAGED file exists and remove it
externally_managed_file=$(find /usr/lib/python3.*/EXTERNALLY-MANAGED 2>/dev/null || true)
if [[ -n "$externally_managed_file" ]]; then
    sudo python3 -m pip config --global set global.break-system-packages true
fi


sudo apt install python3-pip -y
sudo pip3 install frappe-bench

# Initiate bench in frappe-bench folder, but get a supervisor can't restart bench error...
echo -e "${YELLOW}Initialising bench in frappe-bench folder.${NC}"
echo -e "${LIGHT_BLUE}If you get a restart failed, don't worry, we will resolve that later.${NC}"
bench init frappe-bench --version $bench_version --verbose
echo -e "${GREEN}Bench installation complete!${NC}"
sleep 1

# Prompt user for site name
echo -e "${YELLOW}Preparing for Production installation. This could take a minute... or two so please be patient.${NC}"
echo -e "${LIGHT_BLUE}Enter the site name. '.t-erp.co.za' will be automatically appended to your input.${NC}"
read -p "Site name: " user_input
site_name="${user_input}.t-erp.co.za"
echo -e "${GREEN}Your full site name is: $site_name${NC}"
sleep 1

# Prompt for admin password
adminpasswrd=$(ask_twice "Enter the Administrator password" "true")
echo -e "\n"
sleep 2
echo -e "${YELLOW}Now setting up your site. This might take a few minutes. Please wait...${NC}"
sleep 1
# Change directory to frappe-bench
cd frappe-bench && \

sudo chmod -R o+rx /home/$(echo $USER)

bench new-site $site_name --db-root-password $sqlpasswrd --admin-password $adminpasswrd

# Prompt user to confirm if they want to install ERPNext

# Notify the user about ERPNext installation
echo -e "${GREEN}Proceeding with ERPNext installation...${NC}"
sleep 2

# Setup supervisor and nginx config
echo -e "${YELLOW}Setting up ERPNext...${NC}"
bench get-app erpnext --branch $bench_version && \
bench --site $site_name install-app erpnext

# Check if the installation was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}ERPNext has been successfully installed.${NC}"
else
    echo -e "${RED}An error occurred during ERPNext installation. Please check the logs for more information.${NC}"
fi
sleep 1

# Dynamically set the Python version for the playbook file path
python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
playbook_file="/usr/local/lib/python${python_version}/dist-packages/bench/playbooks/roles/mariadb/tasks/main.yml"
sudo sed -i 's/- include: /- include_tasks: /g' $playbook_file

# Production setup
echo -e "${YELLOW}Installing packages and dependencies for Production...${NC}"
sleep 2
# Setup supervisor and nginx config
yes | sudo bench setup production $USER && \
echo -e "${YELLOW}Applying necessary permissions to supervisor...${NC}"
sleep 1
# Change ownership of supervisord.conf
# Path to the supervisord.conf file
FILE="/etc/supervisor/supervisord.conf"
# Construct the search pattern with the current $USER environment variable
SEARCH_PATTERN="chown=$USER:$USER"

# Check if the pattern exists in the file
if grep -q "$SEARCH_PATTERN" "$FILE"; then
    echo -e "${YELLOW}User ownership already exists for supervisord. Updating it...${NC}"
    # Replace the existing line with the new user ownership line
    sudo sed -i "/chown=.*/c $SEARCH_PATTERN" "$FILE"
else
    echo -e "${YELLOW}User ownership does not exist for supervisor. Adding it...${NC}"
    # Insert the new user ownership line at a specific line number
    sudo sed -i "5a $SEARCH_PATTERN" "$FILE"
fi

# Restart supervisor
sudo service supervisor restart && \

# Setup production again to reflect the new site
yes | sudo bench setup production $USER && \

echo -e "${YELLOW}Enabling Scheduler...${NC}"
sleep 1
# Enable and resume the scheduler for the site
bench --site $site_name scheduler enable && \
bench --site $site_name scheduler resume && \
if [[ "$bench_version" == "version-15" ]]; then
    echo -e "${YELLOW}Setting up Socketio, Redis and Supervisor...${NC}"
    sleep 1
    bench setup socketio
    yes | bench setup supervisor
    bench setup redis
    sudo supervisorctl reload
fi
echo -e "${YELLOW}Restarting bench to apply all changes and optimizing environment pernissions.${NC}"
sleep 1


# Now to make sure the environment is fully setup
sudo chmod 755 /home/$(echo $USER)
sleep 3
printf "${GREEN}Production setup complete! "
printf '\xF0\x9F\x8E\x86'
printf "${NC}\n"
sleep 3

# HRMS installation logic
echo -e "${LIGHT_BLUE}Proceeding with HRMS installation...${NC}"
sleep 2
# First installation attempt
if ! install_hrms; then
    echo -e "${YELLOW}HRMS installation failed. A single failure is not unexpected. Attempting first re-install attempt${NC}"
    uninstall_remove_hrms
    
    # Second installation attempt
    if ! install_hrms; then
        echo -e "${YELLOW}HRMS installation failed again. Attempting second and final re-install attempt${NC}"
        uninstall_remove_hrms
        
        # Third and final installation attempt
        if ! install_hrms; then
            echo -e "${YELLOW}Both attempts to re-install have failed. Removing files so that you may attempt your own installation later.${NC}"
            uninstall_remove_hrms
        fi
    fi
fi

# Whitelabel-Terp Installation logic
echo -e "${LIGHT_BLUE}Proceeding with T-ERP Whitelabel installation...${NC}"
sleep 2

if ! install_whitelabel_terp; then 
    echo -e "${YELLOW}T-ERP Whitelabel installation failed.${NC}"
else
    echo -e "${GREEN}T-ERP Whitelabel installation succeeded.${NC}"
fi
sleep 2


echo -e "${YELLOW}Proceeding with SSL installation...${NC}"
echo -e "${YELLOW}Make sure your domain name is pointed to the IP of this instance and is reachable.${NC}"
sleep 3

# Set E-mail value for SSL
email_address="tech@t-erp.co.za"

# Install Certbot
echo -e "${YELLOW}Installing Certbot...${NC}"
sleep 1
if [ "$DISTRO" == "Debian" ]; then
    echo -e "${YELLOW}Fixing openssl package on Debian...${NC}"
    sleep 4
    sudo pip3 uninstall cryptography -y
    yes | sudo pip3 install pyopenssl==22.0.0 cryptography==36.0.0
    echo -e "${GREEN}Package fixed${NC}"
    sleep 2
fi

# Install Certbot Classic
sudo apt install snapd -y && \
sudo snap install core && \
sudo snap refresh core && \
sudo snap install --classic certbot && \
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Obtain and Install the certificate
echo -e "${YELLOW}Obtaining and installing SSL certificate...${NC}"
sleep 2
if sudo certbot --nginx --non-interactive --agree-tos --email $email_address -d $site_name; then
    echo -e "${GREEN}SSL certificate installed successfully.${NC}"
else
    echo -e "${RED}SSL certificate installation failed. Please check your domain configuration and try again manually.${NC}"
fi
sleep 2

# Now let's deactivate virtual environment
if [ -z "$py_version" ] || [ "$py_major" -lt 3 ] || [ "$py_major" -eq 3 -a "$py_minor" -lt 10 ]; then
    deactivate
fi

echo -e "${GREEN}--------------------------------------------------------------------------------"
echo -e "Congratulations! You have successfully installed ERPNext $version_choice."
echo -e "You can start using your new ERPNext installation by visiting https://$site_name"
echo -e "(if you have enabled SSL and used a Fully Qualified Domain Name"
echo -e "during installation) or http://$server_ip to begin."
echo -e "Install additional apps as required. Visit https://docs.erpnext.com for Documentation."
echo -e "Enjoy using ERPNext!"
echo -e "--------------------------------------------------------------------------------${NC}"

echo -e "${YELLOW}Getting your site ready for development...${NC}"
sleep 2
source ~/.profile
if [[ "$bench_version" == "version-15" ]]; then
    nvm alias default 18
else
    nvm alias default 16
fi
bench use $site_name
bench build
echo -e "${GREEN}Done!"
sleep 5

echo -e "${GREEN}-----------------------------------------------------------------------------------------------"
echo -e "Congratulations! You have successfully installed Frappe and ERPNext $version_choice Development Environment."
echo -e "Start your instance by running bench start to start your server and visiting http://$server_ip:8000"
echo -e "Install additional apps as required. Visit https://frappeframework.com for Developer Documentation."
echo -e "Enjoy development with Frappe!"
echo -e "-----------------------------------------------------------------------------------------------${NC}"

bench --site $site_name migrate
bench restart
benhc --site $site_name clear-cache

