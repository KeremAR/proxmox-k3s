#!/bin/bash

# SSH To the admin VM first
# Note the IP of the admin machine
# ADMIN_VM_IP=$(head -n 1 VM_IPs.txt | cut -d '=' -f2 | xargs)
# ssh -i id_rsa ubuntu@$ADMIN_VM_IP

# Script 5B is an optional script for demonstration purposes and installs an ephemeral nextcloud deployment. 
# The database is the default sqlite3 (has limitations) and there is no persistent storage.
# You can skip on to Script 6 if desired, which uses a mysql database and has persistent storage.

echo ""
echo "########## Optional Test Nextcloud Instance Install (NO PERSISTENT STORAGE) ###########"
echo ""

# Referencing domainname from script 5A
DOMAINNAME=$(grep -oP 'DOMAINNAME=\K[^\n]+' ./5A-domainname-dns.sh | head -n 1)

# Note, the IP of the ingress will be revealed in Step 5B.4
# After Step 5B.4, you will need to make nextcloud.yourexampledomain.com be resolvable (at least internally) to be able to browse to it.
# If you setup the dns server in script 5A, make your devices you plan on accessing the nextcould instance from have DNS pointed to the IP of the admin vm, ie 192.168.100.90
# Otherwise modify your hosts file of your device(s) to resolve the domainname to the IP of the nextcloud instance 
# Make the IP of your ingress correlate to your domain

# Step 5B.1 Install Nextcloud

kubectl create namespace nextcloud
helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo update

# Creating a temp deployment to get default credentials into variables
helm install nextcloud nextcloud/nextcloud --namespace nextcloud

echo ""

kubectl get svc nextcloud -n nextcloud

# Step 5B.2 Make self-signed certificate

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

# Step 5B.3 Define ingress configuration

OUTPUT_FILE2="nextcloud-ingress.yaml"

# Create the YAML content
cat <<EOF > $OUTPUT_FILE2

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
echo "YAML file '$OUTPUT_FILE2' has been created."

# Step 5B.4 Apply and confirm ingress configuration
kubectl apply -f nextcloud-ingress.yaml

echo ""
kubectl get ingress -n nextcloud

echo ""
kubectl get secret nextcloud-tls -n nextcloud

echo ""
echo "Added 30 second delay to give nextcloud instance a chance to start..."
echo "Please wait..."
echo ""

sleep 30

POD_NAME=$(/usr/local/bin/kubectl get pods -n nextcloud -o jsonpath='{.items[0].metadata.name}')

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

# Step 5B.5 Correct the config file to be browsable
echo ""
echo "Now correcting the config file to add in the trusted domain"
echo ""

kubectl exec -it $POD_NAME -n nextcloud -- /bin/bash -c "

CONFIG_PATH=\"/var/www/html/config/config.php\" && \
toppart=\$(head -n 27 \$CONFIG_PATH) && \
bottompart=\$(tail -n +28 \$CONFIG_PATH) && \
newline=\" 'overwriteprotocol' => 'https',\" && \
echo \"\$toppart\$newline\$bottompart\" > \$CONFIG_PATH"

# Using sed to replace all occurrences of "http://localhost" with "https://nextcloud.$DOMAINNAME"
kubectl exec -it $POD_NAME -n nextcloud -- env DOMAINNAME="$DOMAINNAME" /bin/bash -c "
CONFIG_PATH='/var/www/html/config/config.php' && \
sed -i \"s|http://localhost|https://nextcloud.\$DOMAINNAME|g\" \$CONFIG_PATH && \
sed -i \"s|1 => 'nextcloud.kube.home',|1 => 'nextcloud.kube.home', 2 => 'nextcloud.\$DOMAINNAME',|g\" \$CONFIG_PATH && \
cat \$CONFIG_PATH"

# Step 5B.6 Backing up files to reuse if needed
echo ""
echo "Saving the test temporary instance configuration..."
echo ""

[ -d ~/nextcloud-config-test ] && rm -rf ~/nextcloud-config-test
kubectl cp $POD_NAME:/var/www/html/config -n nextcloud ~/nextcloud-config-test > /dev/null 2>&1

# Overwriting the config file from the backup for demonstration purposes
POD_NAME=$(/usr/local/bin/kubectl get pods -n nextcloud -o jsonpath='{.items[0].metadata.name}')
kubectl cp ~/nextcloud-config-test/config.php $POD_NAME:/var/www/html/config -n nextcloud
kubectl exec -it $POD_NAME -n nextcloud -- /bin/bash -c 'chown -R www-data:www-data /var/www/html/config/config.php'
kubectl exec -it $POD_NAME -n nextcloud -- /bin/bash -c 'chmod -R 755 /var/www/html/config/config.php'

echo "Waiting 10 seconds for config file backup and restore test..."
sleep 10

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
echo "There is now a nextcloud deployment but there's more we need to do for database configuration and setting up persistent storage"
echo ""
echo "For testing, first browse to https://nextcloud.$DOMAINNAME and test your login."
echo "The default credentials are admin and changeme"
echo "For first time sign in, you may have to sign in a couple times, or open URL in a new tab."
echo ""
echo "Next move on to the next script #6 for persistent storage"