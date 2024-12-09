# Private Registry Nexus

# Option 1 : Install Automaticly :

1. `git clone git@github.com:mahdiambow/devops_private_registry.git`
2. `cd devops_private_registry`
3. `chmod +x install.sh`
4. `sudo ./install.sh`

# Option 2 : Install Manual :

## Setp 1 : Install Essential Package And Tools And Docker

1 . Install jq :

`sudo apt install jq
`

2 . Install Dependencies:

`sudo apt install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common`

3 . Add Docker's Official GPG Key :

## Adding Docker's Official GPG Key

Run the following command to add Docker's GPG key:

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

4 . Add Docker Repository :

`echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
`

5 . Install Docker :

`sudo apt update
`

`sudo apt install docker-ce docker-ce-cli containerd.io`

6 . Verify Docker Installation:

`sudo docker --version`

7 . Start and Enable Docker:

`sudo systemctl start docker`

`sudo systemctl enable docker
`

## Step 2: Install Docker Compose

1 . Download Docker Compose :

`sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
`

2 . Apply Executable Permissions :

`sudo chmod +x /usr/local/bin/docker-compose
`

3 . Verify Docker Compose Installation :

`docker-compose --version
`

## Step 3: Create `docker-compose.yaml` File

```plaintext
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


```

## Step 4: Create SSL Certification

1 . Create an OpenSSL Configuration File :

`openssl.cnf` :

```plaintext
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
CN = registry.example.com

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = registry.example.com


```

2 . Generate SSL Certificates :

```plaintext


openssl genpkey -algorithm RSA -out privkey.pem

request (CSR)
openssl req -new -key privkey.pem -out cert.csr -config openssl.cnf

openssl x509 -req -in cert.csr -signkey privkey.pem -out fullchain.pem -days 365 -extensions v3_req -extfile openssl.cnf


```

3 . Locate Generated Certificates:

```plaintext


mkdir -p ./certs

cp fullchain.pem ./certs/
cp privkey.pem ./certs/



```

## Step 5: Create `registry.conf` File

```plaintext
server {
    listen 80;
    server_name registry.example.com;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name registry.example.com;

    ssl_certificate /etc/ssl/fullchain.pem;
    ssl_certificate_key /etc/ssl/privkey.pem;

    client_max_body_size 1G;

    location / {
        proxy_pass http://nexus:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

```

## Step 8: Setup `/etc/hosts`

1 . Go to hosts

`vi /etc/hosts`

2 . Append This :

```plaintext
127.0.0.1   registry.example.com
```

## Step 9: Start Docker Compose

`docker-compose down`

`docker-compose up -d
`

## Step 10: Get The Password of Nexus :

`sudo docker exec -it nexus /bin/bash`

you can see the pass word here :

`cat /nexus-data/admin.password`

Username : Admin

## Step 11: After Login To Nexus :

1. Go to setting
2. Go to repositories
3. Click create repository
4. Choose docker(hosted)
5. Put http port on 5000
6. Save it

## Step 12: Push the Images :

1. `docker login registry.example.com`

2. Tag The Docker Image :

`docker tag nginx:latest registry.example.com/nginx:latest`

3 . Push Docker Image:

`docker push registry.example.com/nginx:latest`

4 . You Can Pull :

`docker pull localhost:5000/[your-image]`
