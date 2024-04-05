# Open Liberty on Azure Kubernetes Service & Azure Red Hat OpenShift

This sample project demonstrates how to run your Java, Java EE, Jakarta EE, or MicroProfile application on the Open Liberty runtime and then deploy the containerized application to an Azure Kubernetes Service (AKS) cluster or Azure Red Hat OpenShift (ARO) 4 cluster.

## Prerequisites

Finish the following prerequisites to successfully run this sample project.

1. Install a Java SE implementation per your needs (for example, [AdoptOpenJDK OpenJDK 8 LTS/OpenJ9](https://adoptopenjdk.net/?variant=openjdk8&jvmVariant=openj9)).
2. Install [Maven](https://maven.apache.org/download.cgi) 3.5.0 or higher.
3. Install [Docker](https://docs.docker.com/get-docker/) for your OS.
4. Register a [Docker Hub](https://id.docker.com/) account.
5. Install [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) 2.0.75 or later.
6. Register an Azure subscription. If you don't have one, you can get one for free for one year [here](https://azure.microsoft.com/free).
7. Clone [this repository](https://github.com/majguo/open-liberty-demo) to your local file system.

## Set up Azure Kubernetes Service cluster

Follow tutorial [Quickstart: Deploy an Azure Kubernetes Service cluster using the Azure CLI](https://docs.microsoft.com/azure/aks/kubernetes-walkthrough) to:

* Create an AKS cluster.
* Connect to the cluster.
* Install `kubectl` locally.

### Install Open Liberty Operator on AKS

[Open Liberty Operator](https://github.com/OpenLiberty/open-liberty-operator) now also supports Vanilla Kubernetes, including AKS. To install it on AKS cluster for managing your Open Liberty Application, follow the instructions from the [installation guide](https://github.com/OpenLiberty/open-liberty-operator/tree/master/deploy/releases/0.7.0) after creating and connecting to the AKS cluster:

1. Install Custom Resource Definitions (CRDs) for OpenLibertyApplication.

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/master/deploy/releases/0.7.0/   openliberty-app-crd.yaml
   ```

2. Install cluster-level role-based access.

   ```bash
   OPERATOR_NAMESPACE=default
   WATCH_NAMESPACE='""'

   curl -L https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/master/deploy/releases/0.7.0/openliberty-app-cluster-rbac.yaml \
      | sed -e "s/OPEN_LIBERTY_OPERATOR_NAMESPACE/${OPERATOR_NAMESPACE}/" \
      | kubectl apply -f -
   ```

3. Install the operator.

   ```bash
   curl -L https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/master/deploy/releases/0.7.0/openliberty-app-operator.yaml \
      | sed -e "s/OPEN_LIBERTY_WATCH_NAMESPACE/${WATCH_NAMESPACE}/" \
      | kubectl apply -n ${OPERATOR_NAMESPACE} -f -
   ```

## Set up Azure Red Hat OpenShift cluster

Follow the instructions below to set up an ARO 4 cluster.

1. [Create an Azure Red Hat OpenShift 4 cluster](/azure/openshift/tutorial-create-cluster).
   * **NOTE**: "Get a Red Hat pull secret" **is required for this article**. The pull secret enables your Azure Red Dat OpenShift cluster to find the Open Liberty operator.
   * **NOTE**: Specify `Standard_E4s_v3` as virtual machine size for the worker nodes when [creating the cluster using Azure CLI](https://docs.microsoft.com/cli/azure/aro?view=azure-cli-latest#az-aro-create).
2. [Connect to an Azure Red Hat OpenShift 4 cluster](/azure/openshift/tutorial-connect-cluster).

### Install Open Liberty Operator

After creating and connecting to the cluster, install the [Open Liberty Operator](https://github.com/OpenLiberty/open-liberty-operator).

1. Log in to the OpenShift web console from your browser.
2. Navigate to **Operators** > **OperatorHub** and search for **Open Liberty Operator**.
3. Select **Open Liberty Operator** from the search results.
4. Select **Install**.
5. Select **Subscribe** and wait a minute or two.  
6. Navigate to **Operators** > **OperatorHub**, then select **Installed Operators**.
7. Observe the Open Liberty Operator with status of "Succeeded".  If you do not, trouble shoot and resolve the problem before continuing.

### Install Elasticsearch and Cluster Logging Operators

Follow instructions below to deploy cluster logging to the ARO 4 cluster.

1. [Install the Elasticsearch Operator using the CLI](https://docs.openshift.com/container-platform/4.3/logging/cluster-logging-deploying.html#cluster-logging-deploy-eo-cli_cluster-logging-deploying).
2. [Install the Cluster Logging Operator using the CLI](https://docs.openshift.com/container-platform/4.3/logging/cluster-logging-deploying.html#cluster-logging-deploy-clo-cli_cluster-logging-deploying).
3. [Configure Fluentd to merge JSON log message body](https://kabanero.io/guides/app-logging-ocp-4-2/#configure-fluentd-to-merge-json-log-message-body).

Or just execute the following commands, which come from the above guides listed above.

```bash
cd <path-to-your-local-clone>/deploy/cluster-logging

# Install the Elasticsearch Operator
oc create -f eo-namespace.yaml
oc create -f eo-og.yaml
oc create -f eo-sub.yaml
oc project openshift-operators-redhat
oc create -f eo-rbac.yaml

# Install the Cluster Logging Operator
oc create -f clo-namespace.yaml
oc create -f clo-og.yaml
oc create -f clo-sub.yaml
oc create -f clo-instance.yaml

oc project openshift-logging

# Change the cluster logging instance’s managementState field from "Managed" to "Unmanaged"
oc edit ClusterLogging instance

# Set the environment variable "MERGE_JSON_LOG" to "true"
oc set env ds/fluentd MERGE_JSON_LOG=true
```

## Set up Azure Active Directory

Azure Active Directory (Azure AD) implements OpenID Connect (OIDC), an authentication protocol built on OAuth 2.0, which lets you securely sign in a user from Azure AD to an application. Follow the steps below to set up your Azure AD.

1. [Get an Azure AD tenant](https://docs.microsoft.com/azure/active-directory/develop/quickstart-create-new-tenant). It is very likely your Azure account already has a tenant. Note down your **tenant ID**.
2. [Create a few Azure AD users](https://docs.microsoft.com/azure/active-directory/fundamentals/add-users-azure-active-directory). You can use these accounts or your own to test the application. Note down email addresses and passwords for login.
3. Create an **admin group** to enable JWT (Json Web Token) RBAC (role-based-access-control) functionality. Follow [create a basic group and add members using Azure Active Directory](https://docs.microsoft.com/azure/active-directory/fundamentals/active-directory-groups-create-azure-portal) to create a group with type as **Security** and add one or more members. Note down the **group ID**.
4. [Create a new application registration](https://docs.microsoft.com/azure/active-directory/develop/quickstart-register-app) in your Azure AD tenant. Specify **Redirect URI** to be [https://localhost:9443/ibm/api/social-login/redirect/liberty-aad-oidc-javaeecafe](https://localhost:9443/ibm/api/social-login/redirect/liberty-aad-oidc-javaeecafe). Note down the **client ID**.
   * **NOTE**: You need to come back later to add **Redirect URIs** after the sample application is deployed to the AKS cluster or ARO 4 cluster.
5. Create a new client secret. In the newly created application registration, click **Certificates & secrets** > Select **New client secret** > Provide **a description** and hit **Add**. Note down the generated **client secret** value.
6. Add a **groups claim** into the ID token. In the newly created application registration, click **Token configuration** > Click **Add groups claim** > Select **Security groups** as group types to include in the ID token > Expand **ID** and select **Group ID** in the **Customize token properties by type** section.

## Create an Azure Database for PostgreSQL server

Follow the instructions below to set up an Azure Database for PostgreSQL server for data persistence.

1. [Create an Azure Database for PostgreSQL server](https://docs.microsoft.com/azure/postgresql/quickstart-create-server-database-portal#create-an-azure-database-for-postgresql-server).
   * **NOTE**: In configuring **Basics** step, write down **Admin username** and **Password**.
2. Once your database is created, open **your Azure Database for PostgreSQL server** > **Connection security** > Set **Allow access to Azure services** to **Yes** > Click **+ Add current client IP address** > Click **Save**.
3. Open **your Azure Database for PostgreSQL server** > **Connection strings** > **JDBC**. Write down the **Server name** and **Port number** in ***Server name**.postgres.database.azure.com:**Port number*** format.

## Create a hosted Elasticsearch service on Microsoft Azure

Follow the instructions below to create a deployment for the hosted Elasticsearch service on Microsoft Azure.

1. Sign up for a [free trial](https://www.elastic.co/azure).
2. Log into [Elastic Cloud](https://cloud.elastic.co/login) using your free trial account.
3. Click **Create deployment**.
4. **Name your deployment** > Select **Azure as cloud platform** > **Leave defaults for others** or customize per your needs > Click **Create deployment**.
5. Wait until the deployment is created.
6. Write down **User name**, **Password**, and **Cloud ID** for further usage.

## Build application image

Run the following commands to build application image and push to your Docker Hub repository.

```bash
cd <path-to-your-local-clone>

# Name of container registry, which is in the 'docker.io/<account>' format' for DockerHub
./build.sh <your-container-registry>
```

To verify if the application image works well:

1. run the containerized application with your local Docker.

   ```bash
   docker run -it --rm -p 9443:9443 -e CLIENT_ID=<client ID> -e CLIENT_SECRET=<client secret> -e TENANT_ID=<tenant ID> -e ADMIN_GROUP_ID=<group ID> -e DB_SERVER_NAME=<Server name>.postgres.database.azure.com -e DB_PORT_NUMBER=<Port number> -e DB_NAME=postgres -e DB_USER=<Admin username>@<Server name> -e DB_PASSWORD=<DB_Password> open-liberty-demo:1.0.0
   ```

2. Wait for Open Liberty to start and the application to deploy successfully.
3. Open [https://localhost:9443/](https://localhost:9443/) in your browser to visit the application home page.
4. Press **Control-C** to stop the application and Open Liberty server.

## Deploy the application to the AKS cluster

Run the following commands to deploy the containerized application to the AKS cluster, which distributes logs to the hosted Elasticsearch Service on Azure.

```bash
# Connect to your Kubernetes cluster
az aks get-credentials -g <resource-group-name> -n <cluster-name>

cd <path-to-your-local-clone>

# Run the script with all necessary arguments to deploy application
# Deploy sample application using OpenLibertyApplication CR
./deploy-k8s.sh <your-container-registry> <client ID> <client secret> <tenant ID> <group ID> <Server name>.postgres.database.azure.com <Port number> postgres <Admin username>@<Server name> <DB_Password> <Cloud ID> <Elasticsearch_User name>:<Elasticsearch_Password>
# Deploy sample application using K8S built-in resources
# ./deploy-k8s.sh <your-container-registry> <client ID> <client secret> <tenant ID> <group ID> <Server name>.postgres.database.azure.com <Port number> postgres <Admin username>@<Server name> <DB_Password> <Cloud ID> <Elasticsearch_User name>:<Elasticsearch_Password> false

# Check if deployment succeeded, until you see the console output similar as below
kubectl get deployment -n open-liberty-demo
# NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
# javaee-cafe-aad-postgres-hosted-elasticsearch   1/1     1            1           1m

# Check if service is successfully created, until you see the console output similar as below
kubectl get service -n open-liberty-demo
# NAME                                            TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)                         AGE
# javaee-cafe-aad-postgres-hosted-elasticsearch   LoadBalancer   x.x.x.x       x.x.x.x          9080:30955/TCP,9443:30071/TCP   1m
```

Once the Open Liberty Application is up and running, copy **CLUSTER-IP** of the service from console output.

1. Open your **Azure AD** > **App registrations** > your **registered application** > **Authentication** > Click **Add URI** in **Redirect URIs** section > Input ***https://<copied_CLUSTER-IP_value>/ibm/api/social-login/redirect/liberty-aad-oidc-javaeecafe*** > Click **Save**.
2. Open ***https://<copied_CLUSTER-IP_value>*** in the **InPrivate** window of **Microsoft Edge**, verify the application is secured by Azure AD OpenID Connect and connected to Azure Database for PostgreSQL server.

   1. Sign in as a user, who doesn't belong to the admin group you created before.
   2. Update your password if necessary. Accept permission requested if necessary.
   3. You will see the application home page displayed, where the coffee **Delete** button is **disabled**.
   4. Create new coffees.
   5. Close the **InPrivate** window > open a new **InPrivate** window > sign in as another user, who does belong to the admin group you created before.
   6. Update your password if necessary. Accept permission requested if necessary.
   7. You will see the application home page displayed, where the coffee **Delete** button is **enabled** now.
   8. Create new coffees. Delete existing coffees.

The application logs are shipped to the Elasticsearch cluster, and they can be visualized in the Kinaba web console.

1. Log into [Elastic Cloud](https://cloud.elastic.co/login).
2. Find your deployment from **Elasticsearch Service**, click **Kibana** to open its web console.
3. From the top-left of the home page, click menu icon to expand the top-level menu items. Click **Stack Management** > **Index Patterns** > **Create index pattern**.
4. Set **filebeat-\*** as index pattern. Click **Next step**.
5. Select **@timestamp** as **Time Filter field name** > Click **Create index pattern**.
6. From the top-left of the home page, click menu icon to expand the top-level menu items. Click **Discover**. Check index pattern **filebeat-\*** is selected.
7. Add **host&#46;name**, **loglevel**, and **message** from **Available fields** into **Selected fields**. Discover application logs from the work area of the page.

## Deploy the application to the ARO 4 cluster

Firstly connect to the ARO 4 cluster:

```bash
# Get credentials from console output
az aro list-credentials -g <resource-group-name> -n <cluster-name>
# {
#   "kubeadminPassword": "<kubeadmin-password>",
#   "kubeadminUsername": "kubeadmin"
# }

# Retrieve the API server's address
apiServer=$(az aro show -g <resource-group-name> -n <cluster-name> --query apiserverProfile.url -o tsv)

# Login to the OpenShift cluster's API server
oc login $apiServer -u kubeadmin -p <kubeadmin-password>
```

### Distribute application logs to the hosted Elasticsearch Service on Azure

Run the following commands to deploy the containerized application to the ARO 4 cluster, which distributes logs to the hosted Elasticsearch Service on Azure.

```bash
cd <path-to-your-local-clone>

./deploy-openshift.sh <your-container-registry> <client ID> <client secret> <tenant ID> <group ID> <Server name>.postgres.database.azure.com <Port number> postgres <Admin username>@<Server name> <DB_Password> <Cloud ID> <Elasticsearch_User name>:<Elasticsearch_Password>

# Check if deployment succeeded, until you see the console output similar as below
oc get deployment -n open-liberty-demo
# NAME                                            READY     UP-TO-DATE   AVAILABLE   AGE
# javaee-cafe-aad-postgres-hosted-elasticsearch   1/1       1            1           1m

# Check if route is successfully created, until you see the console output similar as below
oc get route -n open-liberty-demo
# NAME                                            HOST/PORT                                                                                        PATH      SERVICES                                        PORT       TERMINATION   WILDCARD
# javaee-cafe-aad-postgres-hosted-elasticsearch   javaee-cafe-aad-postgres-hosted-elasticsearch-open-liberty-demo.apps.xxxxxxxx.eastus.aroapp.io             javaee-cafe-aad-postgres-hosted-elasticsearch   9443-tcp   reencrypt     None
```

Once the Open Liberty Application is up and running, copy **HOST/PORT** of the service from console output.

1. Open your **Azure AD** > **App registrations** > your **registered application** > **Authentication** > Click **Add URI** in **Redirect URIs** section > Input ***https://<copied_HOST/PORT _value>/ibm/api/social-login/redirect/liberty-aad-oidc-javaeecafe*** > Click **Save**.
2. Open ***https://<copied_HOST/PORT _value>*** in the **InPrivate** window of **Microsoft Edge**, verify the application is secured by Azure AD OpenID Connect and connected to Azure Database for PostgreSQL server. Refer to the steps above on how to log in as user with different roles and create/delete coffees.

The application logs are shipped to the Elasticsearch cluster, and they can be visualized in the Kinaba web console. Refer to the steps above to discover application logs from Kibaba.

### Distribute application logs to the EFK stack installed on ARO 4 cluster

Run the following commands to deploy the containerized application to the ARO 4 cluster, which distributes logs to the EFK stack installed on ARO 4 cluster.

```bash
cd <path-to-your-local-clone>

./deploy-openshift.sh <your-container-registry> <client ID> <client secret> <tenant ID> <group ID> <Server name>.postgres.database.azure.com <Port number> postgres <Admin username>@<Server name> <DB_Password>

# Check if deployment succeeded, until you see the console output similar as below
oc get deployment -n open-liberty-demo
# NAME                                            READY     UP-TO-DATE   AVAILABLE   AGE
# javaee-cafe-aad-postgres-cluster-logging        1/1       1            1           1m

# Check if route is successfully created, until you see the console output similar as below
oc get route -n open-liberty-demo
# NAME                                            HOST/PORT                                                                                        PATH      SERVICES                                        PORT       TERMINATION   WILDCARD
# javaee-cafe-aad-postgres-cluster-logging        javaee-cafe-aad-postgres-cluster-logging-open-liberty-demo.apps.xxxxxxxx.eastus.aroapp.io                  javaee-cafe-aad-postgres-cluster-logging        9443-tcp   reencrypt     None
```

Once the Open Liberty Application is up and running, copy **HOST/PORT** of the service from console output.

1. Open your **Azure AD** > **App registrations** > your **registered application** > **Authentication** > Click **Add URI** in **Redirect URIs** section > Input ***https://<copied_HOST/PORT _value>/ibm/api/social-login/redirect/liberty-aad-oidc-javaeecafe*** > Click **Save**.
2. Open ***https://<copied_HOST/PORT _value>*** in the **InPrivate** window of **Microsoft Edge**, verify the application is secured by Azure AD OpenID Connect and connected to Azure Database for PostgreSQL server. Refer to the steps above on how to log in as user with different roles and create/delete coffees.

The application logs are shipped to the Elasticsearch cluster, and they can be visualized in the Kinaba web console.

1. Log into ARO web console. Click **Monitoring** > **Logging**.
2. In the new opened window, click **Log in with OpenShift**. Log in with user **kubeadmin**.
3. Open **Management** > **Index Patterns** > Select **project.\*** > Click **Refresh field list** icon at top-right of the page.
4. Click **Discover**. Select index pattern **project.\*** from the dropdown list.
5. Add **kubernetes.namespace_name**, **kubernetes.pod_name**, **loglevel**, and **message** from **Available Fields** into **Selected Fields**. Discover application logs from the work area of the page.

## Additional resources

* [Open Liberty](https://openliberty.io/)
* [Azure Red Hat OpenShift](https://azure.microsoft.com/services/openshift/)
* [Open Liberty Operator](https://github.com/OpenLiberty/open-liberty-operator)
* [Open Liberty Server Configuration](https://openliberty.io/docs/ref/config/)
* [Liberty Maven Plugin](https://github.com/OpenLiberty/ci.maven#liberty-maven-plugin)
* [Open Liberty Container Images](https://github.com/OpenLiberty/ci.docker)
* [Secure your application by using OpenID Connect and Azure AD](https://docs.microsoft.com/learn/modules/secure-app-with-oidc-and-azure-ad/)
* [Configure social login as OpenID Connect client](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_sec_sociallogin.html#twlp_sec_sociallogin__openid)
* [Configuring the MicroProfile JSON Web Token](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_sec_json.html)
* [Configuring authorization for applications in Liberty](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/twlp_sec_rolebased.html)
* [Defines a data source configuration](https://openliberty.io/docs/ref/config/#dataSource.html)
* [Hosted Elasticsearch service on Microsoft Azure](https://www.elastic.co/azure)
* [Run Filebeat on Kubernetes](https://www.elastic.co/guide/en/beats/filebeat/current/running-on-kubernetes.html)
* [Open Liberty logging and tracing](https://www.openliberty.io/docs/ref/general/?_ga=2.160860285.1762477551.1592542266-979049641.1573374390#logging.html)
* [Open Liberty Environment Variables](https://github.com/OpenLiberty/open-liberty-operator/blob/master/doc/user-guide.adoc#open-liberty-environment-variables)
