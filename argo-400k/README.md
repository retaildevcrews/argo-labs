
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

helm upgrade -i -n argocd \
  --version 0.0.9\
  --create-namespace \
  --values argo-400k/argocd-initial-objects.yaml \
  argocd-apps argo/argocd-apps

```

Access argo ui:
`kubectl port-forward service/argocd-server -n argocd 8080:443`

Get argo password for admin:
`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

Argo Login
`argocd login localhost:8080 --username admin --password <PasswordFromCommand Above>`

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
  - `Workqueue Depth` panel shows `app_reconciliation_queue` steadily increasing as apps are being registered.
    - TODO: determine if this is expected behavior
  - `Workqueue Depth` panel is not showing `app_operation_processing_queue` as apps are being registered
    - TODO: determine if this is expected behavior
  - > app_reconciliation_queue is used to ensure the consistency between the upstream git repositories and Argo CD’s local cache
  - > app_operation_processing_queue is used to ensure the consistency between the local cache and the downstream Kubernetes clusters
  - <https://itnext.io/sync-10-000-argo-cd-applications-in-one-shot-bfcda04abe5b>
  - <https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/#argocd-application-controller>
