#!/bin/bash

# Check if both parameters are provided
if [ $# -ne 3 ]; then
  echo "Usage: $0 <start> <stop> <batch_interval>"
  exit 1
fi

start=$1
stop=$2
batch_interval=$2

# Iterate and execute the argocd command
for ((i=start; i<=stop; i++))
do
  # Set app name
  app_number=$(printf "%06d" $i)
  app_name=guestbook$app_number

  # Execute the argocd command
  echo "Deploying app: $app_name"
  if ! argocd app create $app_name --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --sync-policy none --sync-option CreateNamespace=true --dest-namespace $app_name --dest-server https://kubernetes.default.svc --directory-recurse --upsert -l testing=argoperf; then
    echo "Failed to execute argocd command. Stopping execution."
    exit 1
  fi

  # Check if sleep interval needs to be applied based on batch interval
  if [ $((i % batch_interval)) -eq 0 ]; then
    echo "Sleeping for 5 seconds..."
    sleep 5
  fi
done
