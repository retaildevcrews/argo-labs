## Step 1: Create an ArgoCD management cluster with AKS

To create a new management cluster in AKS, run the following commands. Otherwise, if you already have an existing AKS cluster, you can skip this step and proceed to connecting to the existing AKS cluster. Change accoring to your liking, specially the `AZURE_DNS_ZONE`:

```bash
export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az account set --subscription $AZURE_SUBSCRIPTION_ID

export CLUSTER_RG=argo-labs
export CLUSTER_NAME=argocd_mgmt
export LOCATION=southcentralus
export IDENTITY_NAME=gitops$RANDOM
export NODE_COUNT=4
export AZ_AKS_VERSION=1.25.6
export AZURE_DNS_ZONE=joaquin.dev
export AZURE_DNS_ZONE_RESOURCE_GROUP=dns
```

Create a resource group for your AKS cluster with the following command, replacing <resource-group> with a name for your resource group and <location> with the Azure region where you want your resources to be located:

```bash
az group create --name $CLUSTER_RG --location $LOCATION
```

To use automatic DNS name updates via external-dns, we need to create a new managed identity and assign the role of DNS Contributor to the resource group containg the zone resource

```bash
export IDENTITY=$(az identity create  -n $IDENTITY_NAME -g $CLUSTER_RG --query id -o tsv)
export IDENTITY_CLIENTID=$(az identity show -g $CLUSTER_RG -n $IDENTITY_NAME -o tsv --query clientId)

echo "Sleeping a bit (35 seconds) to let AAD catch up..."
sleep 35

export DNS_ID=$(az network dns zone show --name $AZURE_DNS_ZONE \
  --resource-group $AZURE_DNS_ZONE_RESOURCE_GROUP --query "id" --output tsv)

az role assignment create --role "DNS Zone Contributor" --assignee $IDENTITY_CLIENTID --scope $DNS_ID
```

Create an AKS cluster with the following command:

```bash
az aks create -k $AZ_AKS_VERSION -y -g $CLUSTER_RG \
    -s Standard_D4s_v3 -c $NODE_COUNT \
    --assign-identity $IDENTITY --assign-kubelet-identity $IDENTITY \
    --network-plugin kubenet -n $CLUSTER_NAME
```

Connect to the AKS cluster:

```bash
az aks get-credentials --resource-group $CLUSTER_RG --name $CLUSTER_NAME
```

# Install Argo Helm Chart with HA Values

Add Helm Repos

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

Install Argo

```bash
helm upgrade -i -n argocd \
  --version 5.36.10 \
  --create-namespace \
  --set redis-ha.metrics.serviceMonitor.enabled=false \
  --set controller.metrics.serviceMonitor.enabled=false \
  --set server.metrics.serviceMonitor.enabled=false \
  --set repoServer.metrics.serviceMonitor.enabled=false \
  --set applicationSet.metrics.serviceMonitor.enabled=false \
  --values argo-400k/gitops/management/argocd/argocd-values.yaml \
  argocd argo/argo-cd

# Wait for all pods to be created and be in running state

kubectl get pods -A

helm upgrade -i -n argocd \
  --version 0.0.9\
  --create-namespace \
  --values argo-400k/argocd-initial-objects.yaml \
  argocd-apps argo/argocd-apps

```

Access the ArgoCD web UI by running the following command, and then open the URL in a web browser (ingress, external-dns and cert-manager take care of certificates and DNS hostname resolution):

```bash
open https://argocd.$AZURE_DNS_ZONE
```

Get argo password for admin:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Argo Login

```bash
argocd login argocd.$AZURE_DNS_ZONE --username admin --password <PasswordFromCommand Above>`
```

Deply Guestbook app

```bash
argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --sync-policy none --dest-namespace default --dest-server https://kubernetes.default.svc --directory-recurse
```

## Testing details

- TODO: cluster setup, where is argo running, where are workloads running
- Goal - reach 400k argo apps

### scenario 1

Setup:

- 1 Argo app per k8s namespace
- Manual argo app sync
- TODO: How many apps to add at once?
- TODO: How long to wait between each round of scaling?

Purpose:

- Find limit of Argo UI usability relative to the number of apps
  - TODO: define usable
- Find upper limit of apps that can be registered(manual sync) to a single Argo instance
- Determine required resources(cpu/memory/pod counts/node count/etc.) for a single Argo instance to manage maximum number of apps
- Document argo configuration values that need to be tuned to support maximum number of apps

Observability:

- Number of Argo related pods
- Memory/CPU usage of Argo related pods
- What other metrics should we track? Anything related to k8s metrics, nodes, etc?

## TBD/TODO

- Register in Argo the target "Applications" Cluster
- Automate to deploy 400k apps

Design Considerations:

- How many apps in a namespace?
- Number of namespaces per cluster?
- Number of Argo projects?
- Number of Argo apps per Argo project?
- TODO: add timing info to helper script to track how long it takes to register apps

General notes on attempt to deploy a lot of Argo apps:

- Argo metrics related to timing are measured in seconds. This is not immediately obvious from docs and other available info.
  - Needed to look at source code to verify
  - <https://github.com/argoproj/argo-cd/blob/6041c0b7ddea3ed45980b58010cfb1bc3585ba06/controller/metrics/metrics.go#L273>
  - info metrics can be found here <https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/>
- Grafana dashboard
  - `Reconciliation Performance` panel is a heat map of how fast, in seconds, Argo is able to reconcile apps
  - > app_reconciliation_queue is used to ensure the consistency between the upstream git repositories and Argo CD’s local cache
  - > app_operation_processing_queue is used to ensure the consistency between the local cache and the downstream Kubernetes clusters
  - <https://itnext.io/sync-10-000-argo-cd-applications-in-one-shot-bfcda04abe5b>
  - <https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/#argocd-application-controller>
  - <https://terrytangyuan.github.io/2022/01/11/unveil-the-secret-ingredients-of-continuous-delivery-at-enterprise-scale-with-argocd-kubecon-china-2021/#too-many-applications>

Things to try for better performance:

- TODO:
  - Increase resync period to give time to clear queue, default is 3 mins
  - Increase controller.status.processors to use more workers to clear queue, default is 20
  - Tweak application controller resource usage
    - Reduce the number of replicas to 1 and make the cpu and memory requests very high
    - The application controller replica count affects the performance relative to the number of Clusters and not Applications
    - <https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/#argocd-application-controller>

## Scaling notes

At 5k Argo apps with helm values, <https://github.com/retaildevcrews/argo-labs/blob/febc4888e17f509a4daa771ce3b9fdd62c948532/argo-400k/gitops/management/argocd/argocd-values.yaml>.

- UI is taking around 6.3 seconds according to Edge performance dev tools
