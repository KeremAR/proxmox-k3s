#!/bin/bash

########## Nextcloud Instance Install ###########

# Step 5.0 Commit to a resolvable local (or external) domain name

# Define a domain name for your soon to be nextcloud instance suffix, ie nextcloud.example.com  or nextcloud.example.local

# This does not have to be a publicly facing fqdn.
# In my case I have a local fqdn with on-premise DNS for a .com local suffix domain

DOMAINNAME="ne-inc.com"  # Referenced in Step 5.3 and 5.6

# Note, the IP of the ingress will be revealed in Step 5.4
# After Step 5.4, you will need to make nextcloud.<yourdomainyoupick.com> be resolvable
# If you don't have a local DNS server, alternatively you can modify your hosts file
# In this way you could make the IP of your ingress correlate to your domain

# Step 5.1 Install nextcloud

# SSH To the admin VM first
# Note the IP of the admin machine

# ADMIN_VM_IP="192.168.100.6"
# ssh -i id_rsa ubuntu@$ADMIN_VM_IP

kubectl create namespace nextcloud
helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo update

helm install nextcloud nextcloud/nextcloud --namespace nextcloud

export APP_HOST=127.0.0.1
export APP_PASSWORD=$(kubectl get secret --namespace nextcloud nextcloud -o jsonpath="{.data.nextcloud-password}" | base64 --decode)

echo ""

kubectl get svc nextcloud -n nextcloud

# Step 5.2 Make self-signed certificate

echo ""
echo "Creating a self-signed certificate"
echo ""

# Generate the private key
openssl genpkey -algorithm RSA -out nextcloud.key

# Generate the certificate (valid for 365 days)
openssl req -new -key nextcloud.key -out nextcloud.csr -subj "/C=US/ST=/L=/O=NextCloud/CN=nextcloud.$DOMAINNAME"


# Self-sign the certificate
openssl x509 -req -in nextcloud.csr -signkey nextcloud.key -out nextcloud.crt -days 365

# Combine the private key and certificate into a .pem file (if needed)
cat nextcloud.crt nextcloud.key > nextcloud.pem

kubectl create secret tls nextcloud-tls --cert=nextcloud.crt --key=nextcloud.key -n nextcloud


# Step 5.3 Define ingress configuration

# Define the output file
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


# Step 5.4 Apply and confirm ingress configuration

kubectl apply -f nextcloud-ingress.yaml

kubectl get ingress -n nextcloud

kubectl get secret nextcloud-tls -n nextcloud

echo ""
echo "Added 60 second delay to give nextcloud instance a chance to start..."
echo "Please wait..."
echo ""

sleep 60

kubectl get pods -n nextcloud


# Step 5.5 SOMETHING YOU NEED TO MANUALLY DO

# Note, the IP of the ingress has just been revealed at Step 5.4
# You will need to make nextcloud.<yourdomainyoupick.com> be resolvable with the variable you defined in Step 5.0
# If you don't have a local DNS server, alternatively you can modify the hosts file of the device(s) you plan to access your nextcloud instance from (ie your laptop)
# In this way you could make the IP of your ingress correlate to your domain
# This is a prerequisite for Step 5.6 to properly work

# Step 5.6 Correct the config file to be browsable

POD_NAME=$(/usr/local/bin/kubectl get pods -n nextcloud -o jsonpath='{.items[0].metadata.name}')

/usr/local/bin/kubectl exec -it $POD_NAME -n nextcloud -- env DOMAINNAME="$DOMAINNAME" /bin/bash -c "

CONFIG_PATH=\"/var/www/html/config/config.php\" && \
toppart=\$(head -n 26 \$CONFIG_PATH) && \
bottompart=\$(tail -n +27 \$CONFIG_PATH) && \

newline=\"   2 => \\\"nextcloud.\$DOMAINNAME\\\"\" && \
echo \"\$toppart\$newline\$bottompart\" > \$CONFIG_PATH"

# Using sed to replace all occurrences of "http://localhost" with "https://nextcloud.$DOMAINNAME"

/usr/local/bin/kubectl exec -it $POD_NAME -n nextcloud -- env DOMAINNAME="$DOMAINNAME" /bin/bash -c "
CONFIG_PATH=\"/var/www/html/config/config.php\"
sed -i 's|http://localhost|https://nextcloud.$DOMAINNAME|g' \$CONFIG_PATH
cat $CONFIG_PATH"

echo ""
echo "For testing, first browse to https://nextcloud.$DOMAINNAME and test your login."
echo "The default credentials are admin and changeme"
echo "For first time sign in, you may have to sign in a couple times, then open URL in a new tab."
echo ""

# Step 5.7 Backing up files to reuse

echo ""
echo "Saving this original deployment file for safe keeping"
echo ""
echo "There is now a nextcloud deployment but there's more we need to do to get persistent storage"
echo ""

kubectl cp $POD_NAME:/var/www/html/config -n nextcloud ~/nextcloud-config
kubectl get deployment nextcloud -n nextcloud -o yaml > nextcloud-deployment-original.yaml

echo "Next move on to the next script #6 for persistent storage"

