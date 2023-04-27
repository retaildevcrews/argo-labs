# Lab: Flamingo

## Introduction

This lab will walk you through using flamingo subsystem for argo.  The goal of this lab is to demonstrate:

Usage of Flamingo Subsystem for ArgoCD

During the lab you will:

1. Set up 2 k3d clusters - management cluster, and a workload clusters
2. Set up ArgoCD with Flamingo
3. Deploy sample applications

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
    k3d cluster create workload-cluster-1 --kubeconfig-update-default=false
    k3d cluster create argomgmt --kubeconfig-update-default=false
    k3d kubeconfig merge --all -o config-argo
    sed -i'.original' 's/0.0.0.0/host.k3d.internal/g' config-argo
    export KUBECONFIG=config-argo
    kubectl config use-context k3d-argomgmt 
    ```

3. Validate current kubectl context is set to k3d-argomgmt

    ``` bash
    kubectl config current-context
    ```

4. Install Flux

    ``` bash
    flux install
    kubectl wait pods -n flux-system --all --for condition=ready --insecure-skip-tls-verify
    ```

5. Install Argo

    ``` bash
    kubectl create namespace argocd --insecure-skip-tls-verify
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --insecure-skip-tls-verify
    # Wait until all pods are showing 1/1 in ready state
    kubectl wait pods -n argocd --all --for condition=ready --insecure-skip-tls-verify
    ```

6. Expose API Server External to Cluster (run this command in a new zsh terminal so port forwarding remains running)

    ``` bash
    # Forward port to access UI outside of cluster
    export KUBECONFIG=config-argo
    kubectl port-forward svc/argocd-server -n argocd 8080:443  --insecure-skip-tls-verify
    ```

    After this step is complete go back to original terminal to run the rest of the commands

7. Access UI

    1. Get initial password

        ``` bash
        # Get the initial password for installation - make note
        argocd admin initial-password -n argocd
        ````

    2. You can now access UI by going to: <https://localhost:8080>
    3. Log in using User: admin and Password: from step 6.1
    4. Navigate to <https://localhost:8080/user-info>
    5. Click Update Password Button and change to your password of choice
    6. You will then be logged out, log back in using credentials above

8. Add clusters in Argo

    ``` bash
    #Connect to api server 
    argocd login localhost:8080 --username admin --password <same_password_used_in_ui>
    argocd cluster add k3d-workload-cluster-1 --name workload-cluster-1 --insecure-skip-tls-verify
    ```

9. Deploy prometheus via helmrelease locally in management cluster

    ``` bash
    # Create flux helm repo in argo management cluster
    kubectl apply -f repositories/prometheus-helmrepo.yaml
    # Create helm release locally
    kubectl apply -f argoapps/exampleapp-local.yaml
    ```

10. Deploy prometheus via helmrelease to workload-cluster-1

    ``` bash
    # In order to deploy helm release to destination cluster, it must have the flux controllers running locally
    # For this example it will use sourcecontroller as well as helmcontroller
    # Steps
    # Change context to workload cluster context 
    kubectl config use-context k3d-workload-cluster-1
    # Install flux in destination cluster
    flux install
    # Create flux helm repo in destinatino cluster
    kubectl apply -f repositories/prometheus-helmrepo.yaml
    # Return to argomgmt context
    kubectl config use-context k3d-argomgmt
    # Apply prometheus helmrelease example
    kubectl apply -f argoapps/exampleapp-workload.yaml
    ```

11. Clean up

    ``` bash
    k3d cluster delete workload-cluster-1
    k3d cluster delete argomgmt
    unset KUBECONFIG
    rm config-argo
    rm config-argo.original
    ```
