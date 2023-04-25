#!/bin/sh

echo "on-create started" >> $HOME/status

# Change shell to zsh for vscode
sudo chsh --shell /bin/zsh vscode

wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | sudo bash

# Install dyff to make kustomize diff easier
curl --silent --location https://git.io/JYfAY | sudo bash

# install latest flux in ~/.local/bin
curl -s https://fluxcd.io/install.sh |  bash -s - ~/.local/bin
# install flux completions for bash
echo '. <(flux completion bash)' >> ~/.bashrc
# install flux completions for zsh
echo '. <(flux completion zsh)' >> ~/.zshrc

# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# install flux completions for zsh
sudo echo '0.0.0.0         host.k3d.internal' | sudo tee -a /etc/hosts

echo "on-create completed" >> $HOME/status
