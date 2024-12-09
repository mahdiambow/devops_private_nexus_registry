#!/bin/bash


DOMAIN="registry.example.com"
REPO_URL="git@github.com:mahdiambow/devops_private_registry.git"
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
OPENSSL_CNF="./openssl.cnf"
CERTS_DIR="./certs"
REGISTRY_CONF="./registry.conf"

install_automatically() {
  echo "Cloning the repository..."
  git clone "$REPO_URL"
  cd devops_private_registry || exit
  chmod +x install.sh
  sudo ./install.sh
}

install_manually() {
  echo "Step 1: Installing Essential Packages and Docker"
  
  sudo apt install -y jq
  
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
  
  echo "Adding Docker's official GPG key..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo "Adding Docker repository..."
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  echo "Installing Docker..."
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
  
  sudo docker --version

  sudo systemctl start docker
  sudo systemctl enable docker
  
  echo "Step 2: Installing Docker Compose"
  
  sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  
  sudo chmod +x /usr/local/bin/docker-compose

  docker-compose --version
}

create_docker_compose() {
  echo "Creating docker-compose.yaml file..."
  cat > docker-compose.yaml << EOF
services:
  nexus:
    image: sonatype/nexus3:latest
    container_name: nexus
    ports:
      - "8081:8081"
      - "5000:5000"
    volumes:
      - nexus-data:/nexus-data
    environment:
      - INSTALL4J_ADD_VM_PARAMS=-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=/nexus-data/javaprefs
    networks:
      - nexus-network

  nginx:
    image: nginx:latest
    container_name: nginx
    ports:
      - "80:80"
    volumes:
      - ./registry.conf:/etc/nginx/conf.d/registry.conf
      - ./certs:/etc/ssl/
    networks:
      - nexus-network

volumes:
  nexus-data:
    driver: local

networks:
  nexus-network:
    driver: bridge
EOF
}

create_ssl_certificates() {
  echo "Creating SSL Certificates..."

  cat > "$OPENSSL_CNF" << EOF
[ req ]
default_bits = 2048
default_keyfile = privkey.pem
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[ req_distinguished_name ]
C = US
ST = State
L = City
O = Your Organization
OU = Your Organizational Unit
CN = $DOMAIN

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $DOMAIN
EOF

  openssl genpkey -algorithm RSA -out privkey.pem
  openssl req -new -key privkey.pem -out cert.csr -config "$OPENSSL_CNF"
  openssl x509 -req -in cert.csr -signkey privkey.pem -out fullchain.pem -days 365 -extensions v3_req -extfile "$OPENSSL_CNF"

  mkdir -p "$CERTS_DIR"
  cp fullchain.pem "$CERTS_DIR/"
  cp privkey.pem "$CERTS_DIR/"
}

create_registry_conf() {
  echo "Creating registry.conf file..."
  cat > "$REGISTRY_CONF" << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/ssl/fullchain.pem;
    ssl_certificate_key /etc/ssl/privkey.pem;

    client_max_body_size 1G;

    location / {
        proxy_pass http://nexus:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
}

setup_hosts() {
  echo "Setting up /etc/hosts..."
  echo "127.0.0.1   $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
}

start_docker_compose() {
  echo "Starting Docker Compose..."
  docker-compose down
  docker-compose up -d
}

echo "Choose the installation option: 1 for Automatic, 2 for Manual"
read -p "Enter option number (1/2): " choice

if [ "$choice" -eq 1 ]; then
  install_automatically
elif [ "$choice" -eq 2 ]; then
  install_manually
  create_docker_compose
  create_ssl_certificates
  create_registry_conf
  setup_hosts
  start_docker_compose
else
  echo "Invalid choice. Exiting."
  exit 1
fi

echo "Setup completed. Follow the remaining manual steps as per the instructions."
