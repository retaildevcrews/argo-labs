
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

Design Considerations:

- 1 app per namespace?
- Test Setup/Design
- Resource Requirements for each app? (argo guestbook app)
