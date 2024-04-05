#!/bin/sh

# Environment variables
export CONTAINER_REGISTRY=${1}
export CLIENT_ID=${2}
export CLIENT_SECRET=${3}
export TENANT_ID=${4}
export ADMIN_GROUP_ID=${5}
export DB_SERVER_NAME=${6}
export DB_PORT_NUMBER=${7}
export DB_NAME=${8}
export DB_USER=${9}
export DB_PASSWORD=${10}
export ELASTIC_CLOUD_ID=${11}
export ELASTIC_CLOUD_AUTH=${12}
useOperator=${13}

# Create Namespace "open-liberty-demo"
NAMESPACE=open-liberty-demo
kubectl create namespace ${NAMESPACE}

# Create Secret "aad-oidc-secret"
envsubst < deploy/aad-oidc-secret.yaml | kubectl create -f -

# Create Secret "db-secret-postgres"
envsubst < deploy/db-secret.yaml | kubectl create -f -

# Create ConfigMap "filebeat-config"
kubectl create -f deploy/filebeat-config.yaml

# Create Secret "elastic-cloud-secret"
envsubst < deploy/elastic-cloud-secret.yaml | kubectl create -f -

# Create Deployment & Service instances which connects to hosted elasticsearch service
if [ "$useOperator" != false ]; then
    # Create TLS private key and certificate, which is also used as CA certificate for testing purpose
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt

    # Create environment variables which will be passed to secret "tls-crt-secret"
    export CA_CRT=$(cat tls.crt | base64 -w 0)
    export DEST_CA_CRT=$(cat tls.crt | base64 -w 0)
    export TLS_CRT=$(cat tls.crt | base64 -w 0)
    export TLS_KEY=$(cat tls.key | base64 -w 0)

    # Create secret "tls-crt-secret"
    envsubst < deploy/tls-crt-secret.yaml | kubectl create -f -

    # Use OpenLibertyApplication CR to deploy the sample application
    envsubst < deploy/ola-k8s-hosted-elasticsearch.yaml | kubectl create -f -
else
    # Use deployment/service to deploy the sample application
    envsubst < deploy/k8s-hosted-elasticsearch.yaml | kubectl create -f -
fi

echo "The application is succesfully deployed to project ${NAMESPACE}!"
