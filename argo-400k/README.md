
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
  --values argo-400k/argocd/argocd-values.yaml \
  argocd argo/argo-cd
```

Access argo ui:
`kubectl port-forward service/argocd-server -n argocd 8080:443`

Get argo password for admin:
`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

Argo Login
`argocd --port-forward --port-forward-namespace argocd --grpc-web --plaintext login --username admin --password <PasswordFromCommand Above>`

Deply Guestbook app

```bash
argocd --port-forward --port-forward-namespace argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --sync-policy none --dest-namespace default --dest-server https://kubernetes.default.svc --directory-recurse
```

TBD/TODO:

- Register in Argo the target "ApplicationS" Cluster
- Automate to deploy 400k apps
- observability dashboard
  - other than cpu and memory, what other metrics should be tracked?

Design Considerations:

- 1 app per namespace?
- Test Setup/Design
  - number of namespaces?
  - number of apps per namespace?
  - number of argo projects?
  - how many clusters to distribute the 400k apps?
    - nodes have a max pod count limit
- Resource Requirements for each app? (argo guestbook app)

Questions about 400k number to aid in design:

- does the number include multiple environments (dev, test, prod)?
- is there a 1 to 1 mapping of app deployements and argo applications?
  - example: a product has a web ui deployment and a backend api deployment. would that be 1 argo application with 2 deployments, or 2 argo applications each with 1 deployment?
