#!/bin/bash

# SSH To the admin VM first
# Note the IP of the admin machine

# ADMIN_VM_IP=$(cat ADMIN_VM_IP.txt)
# ssh -i id_rsa ubuntu@$ADMIN_VM_IP

echo ""
echo "########## Nextcloud Instance Install with MySQL and Persistent Storage ###########"
echo ""

cat <<EOF 
                 _       _                 _
 _ __   _____  _| |_ ___| | ___  _   _  __| |
|  _ \ / _ \ \/ / __/ __| |/ _ \| | | |/ _  |
| | | |  __/>  <| || (__) | (_) | |_| | (_) |
|_| |_|\___/_/\_\\__\____|_|\___/ \____|\____|
                                           
EOF
echo ""

# Referencing domainname from script 5A
DOMAINNAME=$(grep -oP 'DOMAINNAME=\K[^\n]+' ./5A-domainname-dns.sh)

# Note, the IP of the ingress will be revealed in Step 6.8
# After Step 6.8, you will need to make nextcloud.yourexampledomain.com be resolvable (at least internally) to be able to browse to it.
# If you setup the dns server in script 5A, make your devices you plan on accessing the nextcould instance from have DNS pointed to the IP of the admin vm, ie 192.168.100.90
# Otherwise modify your hosts file of your device(s) to resolve the domainname to the IP of the nextcloud instance 
# https://nextcloud.$DOMAINNAME 

# Define parameters here
###################################################################################

# Set MySQL DB persistent volume size. Use Gi for unit. ie 8Gi 
MYSQL_DB_SIZE=8Gi

# Set Nextcloud data repository persistent volume size. Use Gi for unit. ie 60Gi 
NEXTCLOUD_DATA_SIZE=60Gi

###################################################################################

## Beginning deployment process ##

# Step 6.0 Check if the namespace exists, then prompt for deletion

kubectl get namespace nextcloud &>/dev/null

# If the namespace exists, prompt the user for deletion
if [ $? -eq 0 ]; then
    echo "Namespace 'nextcloud' exists from a previous deployment."
    echo ""
    # Loop until a valid input is received
    while true; do
        read -p "Are you sure you want to delete the 'nextcloud' namespace and all deployments within it? This action cannot be undone (y/n): " choice
        
        case "$choice" in
            y|Y ) 
                # Deleting the namespace
                echo ""
                echo "Deleting the 'nextcloud' namespace. Please wait..."
                echo "This may take a minute..."
                echo ""

                kubectl delete deployment nextcloud -n nextcloud

                kubectl delete namespace nextcloud
                kubectl create namespace nextcloud
                break
                ;;
            n|N ) 
                echo "The 'nextcloud' namespace was not deleted. Exiting..."
                exit 0
                ;;
            * ) 
                echo "Invalid choice. Please enter 'y' for yes or 'n' for no."
                # Loop will repeat here
                ;;
        esac
    done
fi

kubectl get namespace nextcloud || kubectl create namespace nextcloud

echo ""

# Step 6.1 Installing Nextcloud as an init instance

echo "Installing Nextcloud as init instance to get config file template. This uses sqlite and will be deleted."
echo ""

helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo update

# Deployment of nextcloud
helm install nextcloud nextcloud/nextcloud --namespace nextcloud

export APP_PASSWORD=$(kubectl get secret --namespace nextcloud nextcloud -o jsonpath="{.data.nextcloud-password}" | base64 --decode)

while true; do
  POD_NAME=$(/usr/local/bin/kubectl get pods -n nextcloud -o jsonpath='{.items[0].metadata.name}')
  if [[ -n "$POD_NAME" ]]; then
    echo "Found pod: $POD_NAME"
    break
  else
    echo "Pod not found yet, retrying in 5 seconds..."
    sleep 5
  fi
done

# Step 6.2A Install MariaDB using Helm

echo ""
echo "Installing MariaDB MySQL"
echo ""

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install MariaDB chart

helm install mariadb bitnami/mariadb \
  --namespace nextcloud \
  --set global.database.persistence.enabled=true \
  --set global.database.persistence.size=$MYSQL_DB_SIZE
	
echo ""	
echo "Waiting 30 seconds tp check for MariaDB pod readiness. Please wait..."
echo ""

sleep 30

echo "Waiting for MariaDB pod to start. This may take a couple minutes..."
echo ""
	
  # Loop until the pod is in Ready state
while true; do
  # Get the pod status using kubectl
  POD_STATUS=$(kubectl get pod mariadb-0 -n nextcloud -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

  # Check if the pod status is "True" (Ready)
  if [[ "$POD_STATUS" == "True" ]]; then
    echo "Pod mariadb-0 is Ready."
    break
  else
    echo "Pod mariadb-0 is not Ready yet. Checking again..."
    sleep 5  # Wait for 5 seconds before checking again
  fi
done

echo ""

# Step 6.2B Customize mysql mariadb with new nextcloud database and new nextcloud user

MARIADB_ROOT_PASSWORD=$(kubectl get secret --namespace nextcloud mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 -d)

# Define variables
DB_NAME="nextcloud"
DB_USER="nextcloud"
DB_PASSWORD=$MARIADB_ROOT_PASSWORD

# Connect to MariaDB container and log in using mariadb binary
while true; do
  echo "Attempting to connect to MariaDB..."
  kubectl exec -it -n nextcloud mariadb-0 -- bash -c "/opt/bitnami/mariadb/bin/mariadb -u root -p$MARIADB_ROOT_PASSWORD -e 'SHOW DATABASES;'" && break
  echo "Connection failed, retrying in 5 seconds..."
  echo ""
  sleep 5
done

echo ""

# Check if the database exists
while true; do
  echo "Checking if MariaDB is ready..."
  DATABASE_EXISTS=$(kubectl exec -n nextcloud mariadb-0 -- bash -c "/opt/bitnami/mariadb/bin/mariadb -u root -p$MARIADB_ROOT_PASSWORD -e \"SHOW DATABASES LIKE '$DB_NAME';\" 2>/dev/null")

  if [[ $? -eq 0 ]]; then
    echo "Successfully connected to MariaDB."
    break
  else
    echo "Failed to connect to MariaDB. Retrying in 5 seconds..."
    sleep 5
  fi
done

echo ""

if [[ -z "$DATABASE_EXISTS" ]]; then
  echo "Database '$DB_NAME' does not exist. Creating database..."
  kubectl exec -n nextcloud mariadb-0 -- bash -c "/opt/bitnami/mariadb/bin/mariadb -u root -p$MARIADB_ROOT_PASSWORD -e \"CREATE DATABASE $DB_NAME;\""
else
  echo "Database '$DB_NAME' already exists."
fi

# Check if the user exists in the user table
USER_EXISTS=$(kubectl exec -it -n nextcloud mariadb-0 -- bash -c "/opt/bitnami/mariadb/bin/mariadb -u root -p$MARIADB_ROOT_PASSWORD -e \"SELECT User FROM mysql.user WHERE User = '$DB_USER';\"")

if [[ -z "$USER_EXISTS" ]]; then
    echo "User '$DB_USER' does not exist. Creating user..."
    kubectl exec -it -n nextcloud mariadb-0 -- bash -c "/opt/bitnami/mariadb/bin/mariadb -u root -p$MARIADB_ROOT_PASSWORD -e \"CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';\""
else
    echo "User '$DB_USER' exists."
fi

echo ""
echo "Confirming MariaDB pod is still in Ready state..."
echo ""

sleep 10

# Wait until the pod is marked "Ready"
while true; do
  POD_STATUS=$(kubectl get pod mariadb-0 -n nextcloud -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  if [[ "$POD_STATUS" == "True" ]]; then
    echo "Pod mariadb-0 is Ready."
    break
  else
    echo "Pod mariadb-0 is not Ready yet. Checking again in 10s..."
    sleep 10
  fi
done

# Wait for MariaDB to be responsive
while true; do
  echo ""
  echo "Waiting for MariaDB to be ready before GRANT/FLUSH..."
  kubectl exec -n nextcloud mariadb-0 -- bash -c "/opt/bitnami/mariadb/bin/mariadb -u root -p$MARIADB_ROOT_PASSWORD -e 'SELECT 1;'" &> /dev/null

  if [[ $? -eq 0 ]]; then
    echo "MariaDB is responding. Proceeding..."
    break
  else
    echo "Still waiting for DB readiness... retrying in 10s."
    sleep 10
  fi
done

# Run GRANT and FLUSH with retries
MAX_RETRIES=5
RETRY_COUNT=0

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
  echo ""
  echo "Attempting to GRANT privileges (try $((RETRY_COUNT + 1))/$MAX_RETRIES)..."

  GRANT_OUTPUT=$(kubectl exec -n nextcloud mariadb-0 -- bash -c \
    "/opt/bitnami/mariadb/bin/mariadb -u root -p$MARIADB_ROOT_PASSWORD -e \
    \"GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%'; FLUSH PRIVILEGES;\"" 2>&1)

  echo "$GRANT_OUTPUT"

  if echo "$GRANT_OUTPUT" | grep -qE "TLS/SSL error|OCI runtime|setns process|error executing command"; then
    echo "Detected transient error during GRANT. Retrying in 10s..."
    ((RETRY_COUNT++))
    sleep 10
  elif echo "$GRANT_OUTPUT" | grep -qi "ERROR"; then
    echo "Non-transient MySQL error encountered. Aborting."
    exit 1
  else
    echo "Privileges successfully granted!"
    break
  fi
done

if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
  echo "Exceeded maximum retries. GRANT command failed."
  exit 1
fi


echo ""
echo "MariaDB setup is complete!"
echo ""
echo "Now deploying temp pod to get Nextcloud config to persistent storage."
echo ""

# Step 6.3 Create persistent volume claims for Nextcloud and create temp pod

 # Define the output file
OUTPUT_FILE1="create-nextcloud-pvc.yaml"

# Create the YAML content
cat <<EOF > $OUTPUT_FILE1

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-config-pvc
  namespace: nextcloud
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Mi
  storageClassName: longhorn

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-data-pvc
  namespace: nextcloud
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $NEXTCLOUD_DATA_SIZE
  storageClassName: longhorn

---
apiVersion: v1
kind: Pod
metadata:
  name: nextcloud-temp-pod
  namespace: nextcloud
spec:
  containers:
  - name: nextcloud-temp-container
    image: busybox:1.35.0-uclibc
    command: [ "sleep", "3600" ] 
    volumeMounts:
    - mountPath: /var/www/html/config
      name: nextcloud-config
    - mountPath: /var/www/html/data
      name: nextcloud-data
  volumes:
  - name: nextcloud-config
    persistentVolumeClaim:
      claimName: nextcloud-config-pvc
  - name: nextcloud-data
    persistentVolumeClaim:
      claimName: nextcloud-data-pvc

EOF

# Confirm the file was created
echo "YAML file '$OUTPUT_FILE1' has been created."
echo ""

kubectl apply -f create-nextcloud-pvc.yaml

echo ""
echo "Showing Persistent Volume Claims."
echo ""
kubectl get pvc -n nextcloud
echo ""

# Step 6.4A Copy nextcloud config to temp local folder

echo "Checking for nextcloud init pod readiness..."
echo ""

# Loop until the pod is in Ready state
while true; do
  # Get the pod status using kubectl
  POD_STATUS=$(kubectl get pod "$POD_NAME" -n nextcloud -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

  # Check if the pod status is "True" (Ready)
  if [[ "$POD_STATUS" == "True" ]]; then
    echo "Pod $POD_NAME is Ready."
    break
  else
    echo "Pod $POD_NAME is not Ready yet. Checking again..."
    sleep 5  # Wait for 5 seconds before checking again
  fi
done

echo "Copying nextcloud config to a local temp folder"
echo ""

[ -d ~/nextcloud-config-init-temp ] && rm -rf ~/nextcloud-config-init-temp
kubectl cp $POD_NAME:/var/www/html/config -n nextcloud ~/nextcloud-config-init-temp  > /dev/null 2>&1

cat ~/nextcloud-config-init-temp/config.php

echo ""

echo ""
echo "Next the config file will be copied to the temp pod once it is available..."
echo ""

# Loop until the pod is in Ready state
while true; do
  # Get the pod status using kubectl
  POD_STATUS=$(kubectl get pod nextcloud-temp-pod -n nextcloud -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

  # Check if the pod status is "True" (Ready)
  if [[ "$POD_STATUS" == "True" ]]; then
    echo "Pod nextcloud-temp-pod is Ready."
    break
  else
    echo "Pod nextcloud-temp-pod is not Ready yet. Checking again..."
    sleep 5  # Wait for 5 seconds before checking again
  fi
done

echo ""

kubectl get pods -n nextcloud

# Step 6.4B Copy the config files from a local folder to to the persistent volume (currently attached to temp pod)

kubectl cp ~/nextcloud-config-init-temp/. nextcloud-temp-pod:/var/www/html/config/ -n nextcloud 

echo ""
echo "Config file copied. Displaying it now..."
echo "Note configuration still uses sqlite. This will be corrected in the last few steps."
echo ""

kubectl exec -it nextcloud-temp-pod -n nextcloud -- /bin/sh -c 'cat /var/www/html/config/config.php'

# Step 6.4C Delete the temporary pod and temp folder
echo ""
echo "Deleting the temporary pod, please wait..."
echo ""

kubectl delete pods nextcloud-temp-pod -n nextcloud

echo ""

# Delete init temp config folder as it is no longer needed
rm -rf ~/nextcloud-config-init-temp/

# Step 6.5A Get current deployment in YAML, then create a new YAML deployment file with customized persistent volume settings

# Export init deployment to a YAML file to setup persistent storage
[ -f nextcloud-deployment-init.yaml ] && rm nextcloud-deployment-init.yaml
kubectl get deployment nextcloud -n nextcloud -o yaml > nextcloud-deployment-init.yaml

# File paths
INIT_YAML="nextcloud-deployment-init.yaml"
OUTPUT_YAML="nextcloud-deployment-with-pvc.yaml"
[ -f nextcloud-deployment-with-pvc.yaml ] && rm nextcloud-deployment-with-pvc.yaml

IMAGE=$(grep -oP 'image:\s*\K.*' "$INIT_YAML" | head -n 1)

# Create the output YAML by copying the init file as a starting point
cp "$INIT_YAML" "$OUTPUT_YAML"

cat <<EOL >> "$OUTPUT_YAML"

spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/component: app
      app.kubernetes.io/instance: nextcloud
      app.kubernetes.io/name: nextcloud
  template:
    metadata:
      labels:
        app.kubernetes.io/component: app
        app.kubernetes.io/instance: nextcloud
        app.kubernetes.io/name: nextcloud
    spec:
      containers:
        - name: nextcloud
          image: $IMAGE
          volumeMounts:
            - mountPath: /var/www/
              name: nextcloud-main
              subPath: root
            - mountPath: /var/www/html
              name: nextcloud-main
              subPath: html
            - mountPath: /var/www/html/data
              name: nextcloud-data
              subPath: data
            - mountPath: /var/www/html/config
              name: nextcloud-config
              subPath: config
            - mountPath: /var/www/html/custom_apps
              name: nextcloud-main
              subPath: custom_apps
            - mountPath: /var/www/tmp
              name: nextcloud-main
              subPath: tmp
            - mountPath: /var/www/html/themes
              name: nextcloud-main
              subPath: themes
      volumes:
        - name: nextcloud-main
          emptyDir: {}
        - name: nextcloud-data
          persistentVolumeClaim:
            claimName: nextcloud-data-pvc
        - name: nextcloud-config
          persistentVolumeClaim:
            claimName: nextcloud-config-pvc
EOL

echo "Updated YAML has been saved to $OUTPUT_YAML"

# Output success message
echo "Persistent storage configuration added successfully. Output YAML file: $OUTPUT_YAML"
echo "Deleting init deployment to add deployment with persistent storage..."
echo ""

# Step 6.5B Delete current next deployment and apply one with persistent storage

kubectl delete deployment nextcloud -n nextcloud

kubectl apply -f nextcloud-deployment-with-pvc.yaml
rm nextcloud-deployment-init.yaml

echo ""

kubectl get pods -n nextcloud

echo ""
echo "Waiting 60 seconds for persistent storage Nextcloud pod to start. Please wait..."
echo ""

sleep 60

POD_NAME=$(kubectl get pods -n nextcloud --no-headers | grep -v maria | awk '{print $1}' | head -n 1)

# Loop until the pod is in Ready state
while true; do
  # Get the pod status using kubectl
  POD_STATUS=$(kubectl get pod "$POD_NAME" -n nextcloud -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

  # Check if the pod status is "True" (Ready)
  if [[ "$POD_STATUS" == "True" ]]; then
    echo "Pod $POD_NAME is Ready."
    break
  else
    echo "Pod $POD_NAME is not Ready yet. Checking again..."
    sleep 5  # Wait for 5 seconds before checking again
  fi
done

echo ""

kubectl get pods -n nextcloud

echo ""
echo "Persistent storage setup complete. Next we'll connect the database..."
echo ""

# Step 6.6 Modification of default database to use mysql

echo "Removing default deployment data of sqlite database"
echo ""

#kubectl exec -it $POD_NAME -n nextcloud -- sed -i "/'installed' => true,/d" /var/www/html/config/config.php
kubectl exec -it $POD_NAME -n nextcloud -- /bin/bash -c "rm -rf /var/www/html/data/*"

kubectl exec -n nextcloud "$POD_NAME" -- bash -c "
  while [ ! -f /var/www/html/lib/versioncheck.php ]; do
    echo 'Waiting for Nextcloud files to be ready...'
    sleep 5
  done

  echo 'Nextcloud files are ready. '"

echo ""

  # Confirm MariaDB pod is still in Ready state
while true; do
  # Get the pod status using kubectl
  POD_STATUS=$(kubectl get pod mariadb-0 -n nextcloud -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

  # Check if the pod status is "True" (Ready)
  if [[ "$POD_STATUS" == "True" ]]; then
    echo "Pod mariadb-0 is Ready."
    break
  else
    echo "Pod mariadb-0 is not Ready yet. Checking again..."
    sleep 5  # Wait for 5 seconds before checking again
  fi
done

while true; do
  echo ""
  echo "Waiting for MariaDB to be ready before connecting nextcloud..."
  kubectl exec -n nextcloud mariadb-0 -- bash -c "/opt/bitnami/mariadb/bin/mariadb -u root -p$MARIADB_ROOT_PASSWORD -e 'SELECT 1;' 2>/dev/null"

  if [[ $? -eq 0 ]]; then
    echo "MariaDB is ready. Proceeding with nextcloud connection..."
    break
  else
    echo "Still waiting... retrying in 5 seconds."
    sleep 5
  fi
done
  
echo ""
echo "Updating database to MySQL. Please wait..."

while true; do
  echo ""
  echo "Attempting Nextcloud database installation. This may take a few minutes..."

  INSTALL_OUTPUT=$(kubectl exec -n nextcloud "$POD_NAME" -- bash -c "
    chown -R www-data:www-data /var/www/html && \
    su -s /bin/bash -c 'php /var/www/html/occ maintenance:install \
      --database mysql \
      --database-name nextcloud \
      --database-user nextcloud \
      --database-pass $DB_PASSWORD \
      --admin-user admin \
      --admin-pass $APP_PASSWORD \
      --data-dir /var/www/html/data \
      --database-host mariadb' www-data
  " 2>&1)

  echo "$INSTALL_OUTPUT"

  if echo "$INSTALL_OUTPUT" | grep -q "SQLSTATE\[HY000\]: General error: 2006 MySQL server has gone away"; then
    echo "MariaDB dropped connection during install. Retrying in 10 seconds..."
    sleep 10

  elif echo "$INSTALL_OUTPUT" | grep -q "SQLSTATE\[HY000\] \[2002\] Connection refused"; then
    echo "MariaDB connection refused. Retrying in 10 seconds..."
    sleep 10

  else
    echo ""
    echo "Checking Nextcloud installation status with 'occ status'..."

    IS_INSTALLED=$(kubectl exec -n nextcloud "$POD_NAME" -- bash -c "
      su -s /bin/bash -c 'php /var/www/html/occ status' www-data 2>/dev/null | grep -i 'installed:' | awk '{print \$2}'
    ")

    if [[ "$IS_INSTALLED" == "true" ]]; then
      echo "Nextcloud is confirmed as installed. Exiting loop."
      break
    else
      echo "Nextcloud installation failed or incomplete. Retrying in 10 seconds..."
      sleep 10
    fi
  fi
done

echo ""
kubectl get svc nextcloud -n nextcloud
echo ""

kubectl get pods -n nextcloud

echo ""

kubectl exec -it $POD_NAME -n nextcloud -- /bin/sh -c 'cat /var/www/html/config/config.php'

echo ""
echo "Deployment has now linked nextcloud and the mysql database."
echo "Next we need to make this instance browsable."
echo ""

# Begin certificate, ingress, and trusted domain config file modification section

# Step 6.7 Make self-signed certificate

echo ""
echo "Creating a self-signed certificate"
echo ""

# Generate the private key
openssl genpkey -algorithm RSA -out nextcloud.key

echo ""

# Generate the certificate (valid for 365 days)
openssl req -new -key nextcloud.key -out nextcloud.csr -subj "/C=US/ST=/L=/O=NextCloud/CN=nextcloud.$DOMAINNAME" > /dev/null 2>&1

# Self-sign the certificate
openssl x509 -req -in nextcloud.csr -signkey nextcloud.key -out nextcloud.crt -days 365

# Combine the private key and certificate into a .pem file (if needed)
cat nextcloud.crt nextcloud.key > nextcloud.pem

kubectl create secret tls nextcloud-tls --cert=nextcloud.crt --key=nextcloud.key -n nextcloud

# Step 6.8 Define and apply ingress configuration

# Define the output file
OUTPUT_FILE3="nextcloud-ingress.yaml"

# Create the YAML content
cat <<EOF > $OUTPUT_FILE3

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nextcloud-https-ingress
  namespace: nextcloud
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
    - host: nextcloud.$DOMAINNAME
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nextcloud
                port:
                  number: 8080
  tls:
    - hosts:
        - nextcloud.$DOMAINNAME
      secretName: nextcloud-tls
EOF

# Confirm the file was created
echo "YAML file '$OUTPUT_FILE3' has been created."


# Apply and confirm ingress configuration
kubectl apply -f nextcloud-ingress.yaml

kubectl get ingress -n 

echo ""

kubectl get secret nextcloud-tls -n nextcloud

echo ""

# Step 6.9 Adjust config file to correct trusted domain issue

echo "Revising config file"
echo ""

kubectl exec -it $POD_NAME -n nextcloud -- /bin/bash -c "

CONFIG_PATH=\"/var/www/html/config/config.php\" && \
toppart=\$(head -n 26 \$CONFIG_PATH) && \
bottompart=\$(tail -n +27 \$CONFIG_PATH) && \
newline2=\" 'overwriteprotocol' => 'https',\" && \
echo \"\$toppart\$newline2\$bottompart\" > \$CONFIG_PATH"

# Using sed to replace all occurrences of "http://localhost" with "https://nextcloud.$DOMAINNAME"
kubectl exec -it $POD_NAME -n nextcloud -- env DOMAINNAME="$DOMAINNAME" /bin/bash -c "
CONFIG_PATH='/var/www/html/config/config.php' && \
sed -i \"s|http://localhost|https://nextcloud.\$DOMAINNAME|g\" \$CONFIG_PATH && \
sed -i \"s|0 => 'localhost',|0 => 'localhost', 1 => 'nextcloud.\$DOMAINNAME',|g\" \$CONFIG_PATH && \
cat \$CONFIG_PATH"

echo "" 

# Step 6.10 Backing up files to reuse if needed

echo ""
echo "Saving this deployment file for safe keeping..."
echo ""

[ -d ~/nextcloud-config ] && rm -rf ~/nextcloud-config
kubectl cp $POD_NAME:/var/www/html/config -n nextcloud ~/nextcloud-config > /dev/null 2>&1

[ -f nextcloud-deployment-mysql.yaml ] && rm nextcloud-deployment-mysql.yaml
kubectl get deployment nextcloud -n nextcloud -o yaml > nextcloud-deployment-mysql.yaml

# Loop until the pod is in Ready state
while true; do
  # Get the pod status using kubectl
  POD_STATUS=$(kubectl get pod "$POD_NAME" -n nextcloud -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

  # Check if the pod status is "True" (Ready)
  if [[ "$POD_STATUS" == "True" ]]; then
    echo "Pod $POD_NAME is Ready."
    break
  else
    echo "Pod $POD_NAME is not Ready yet. Checking again..."
    sleep 5  # Wait for 5 seconds before checking again
  fi
done

echo ""

kubectl get pods -n nextcloud

####### YOU DID IT!!!! #########

echo ""
echo "YOU DID IT!!!! We now have a nextcloud instance with persistent storage and a mysql database!!"
echo ""

echo ""
echo "Browse to https://nextcloud.$DOMAINNAME and log in."
echo "The default credentials are admin and changeme"
echo "For first time sign in, you may have to sign in a couple times, or open URL in a new tab."
echo ""