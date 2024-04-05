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

# Create Namespace "open-liberty-demo"
NAMESPACE=open-liberty-demo
oc new-project ${NAMESPACE}

# Create Secret "aad-oidc-secret"
envsubst < deploy/aad-oidc-secret.yaml | oc create -f -

# Create TLS private key and certificate, which is also used as CA certificate for testing purpose
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt

# Create Secret "tls-crt-secret"
export CA_CRT=$(cat tls.crt | base64 -w 0)
export DEST_CA_CRT=$(cat tls.crt | base64 -w 0)
export TLS_CRT=$(cat tls.crt | base64 -w 0)
export TLS_KEY=$(cat tls.key | base64 -w 0)
envsubst < deploy/tls-crt-secret.yaml | oc create -f -

# Create Secret "db-secret-postgres"
envsubst < deploy/db-secret.yaml | oc create -f -

# Determine whether hosted elasticsearch service is used
if [ ! -z "$ELASTIC_CLOUD_ID" ] && [ ! -z "$ELASTIC_CLOUD_AUTH" ]; then
    # Create ServiceAccount "filebeat-svc-account"
    oc create -f deploy/filebeat-svc-account.yaml
    oc adm policy add-scc-to-user privileged -n ${NAMESPACE} -z filebeat-svc-account

    # Create ConfigMap "filebeat-config"
    oc create -f deploy/filebeat-config.yaml

    # Create Secret "elastic-cloud-secret"
    envsubst < deploy/elastic-cloud-secret.yaml | oc create -f -
    
    # Create OpenLibertyApplication instance which connects to hosted elasticsearch service 
    envsubst < deploy/ola-openshift-hosted-elasticsearch.yaml | oc create -f -
else
    # Create OpenLibertyApplication instance which connects to cluster logging of OpenShift
    envsubst < deploy/ola-openshift-cluster-logging.yaml | oc create -f -
fi

echo "The application is succesfully deployed to project ${NAMESPACE}!"
