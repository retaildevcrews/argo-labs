FROM ghcr.io/cse-labs/jumpbox:latest

RUN curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
  install -m 555 argocd-linux-amd64 /usr/local/bin/argocd && \
  rm argocd-linux-amd64

WORKDIR /helper_scripts

ADD helper_scripts/ /helper_scripts/

ENTRYPOINT [ "./create_guestbook.sh" ]
