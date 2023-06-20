# Lab: Argo Core Deployment

## Introduction

This lab will walk you through Argo with core deployment:

Core deployment of ArgoCD

During the lab you will:

1. Set up a k3d cluster
2. Deploy sample applications

## Prerequisites (If Running in Codespaces the prerequisites should be installed already in environment)

1. Kubectl - Installation instructions here: <https://kubernetes.io/docs/tasks/tools/>
2. Argo CLI - Installation instructions here: <https://argo-cd.readthedocs.io/en/stable/cli_installation/>
3. Docker - Installation instruction here: <https://docs.docker.com/engine/install/>
   > **Note**
   > You can validate you have docker running by running the following command
   > docker --version
4. k3d-
   > **Note**
   > You can validate you have docker running by running the following command
   > k3d --version

    ``` bash
    #Install latest version of k3d
    wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | sudo bash
    ```

5. Argo CLI - Install Argo CLI by following instructions found here: <https://argo-cd.readthedocs.io/en/stable/cli_installation/>
   > **Note**
   > When running certain commanda like cluster add, argocd cli will make calls to cluster using kubeconfig context's server value.  It will also use this within the argo management cluster to add the destination cluster.  Because the management cluster has no knowledge of the destination server's control plane at the default server in the context which is 0.0.0.0, it will not be able to reach the destination servers control plane.  To get around this we will use the host.k3d.internal feature to provide a dns alias to the server.  To do this we will need to edit your systems hosts file by adding the following entry:  

   ``` bash
   # Added to enable running argocd cli  on local k3d instances
   0.0.0.0         host.k3d.internal
   ```

   Instructions on updating hosts file: <https://www.howtogeek.com/27350/beginner-geek-how-to-edit-your-hosts-file/>

## Steps

> **Note**
> If you are running in a dev container and it stopped and restarted you may need to add an entry to the /etc/hosts file run the following command
>
> ``` bash
> if grep -wq "host.k3d.internal" /etc/hosts; then 
>    echo "Host entry exists for k3d clusters" 
> else 
>    sudo echo '0.0.0.0         host.k3d.internal' | sudo tee -a /etc/hosts
> fi
> ```

1. Ensure you are executing this lab from the flamingo directory

2. Create k3d Clusters

    ``` bash
    # for now only configue one cluster
    k3d cluster create argo-cluster --kubeconfig-update-default=false
    k3d kubeconfig merge --all -o config-argo
    sed -i'.original' 's/0.0.0.0/host.k3d.internal/g' config-argo
    export KUBECONFIG=config-argo
    kubectl config use-context k3d-argo-cluster 
    ```

3. Validate current kubectl context is set to argo-cluster

    ``` bash
    kubectl config current-context
    ```

4. Install Argo

    ``` bash
    kubectl create namespace argocd --insecure-skip-tls-verify
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml --insecure-skip-tls-verify
    # Wait until all pods are showing 1/1 in ready state
    kubectl wait pods -n argocd --all --for condition=ready --insecure-skip-tls-verify
    ```

5. Run the UI from a new terminal

    ``` bash
    # Forward port to access UI outside of cluster
    export KUBECONFIG=config-argo
    kubectl config use-context k3d-argo-cluster
    argocd admin dashboard
    ```

6. Access UI

    1. You can now access UI by going to: <http://127.0.0.1:8080/>

7. Deploy guestbook into the cluster running ArgoCD

    ``` bash
    kubectl delete --all pods --namespace=argocd --insecure-skip-tls-verify
    # Create flux helm repo in argo cluster
    kubectl apply -f app-of-apps.yaml --insecure-skip-tls-verify
    ```

8. Clean up

    ``` bash
    k3d cluster delete argo-cluster
    unset KUBECONFIG
    rm config-argo
    rm config-argo.original
    ```
