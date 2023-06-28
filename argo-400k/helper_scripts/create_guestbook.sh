#!/bin/bash

# Check if both parameters are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 <num_of_apps> <sleep_interval>"
  exit 1
fi

iterations=$1
sleep_interval=$2

# Iterate and execute the argocd command
for ((i=1; i<=iterations; i++))
do
  # Set app name
  app_name=guestbook$i

  # Execute the argocd command
  echo "Deploying app: $app_name"
  if ! argocd --port-forward --port-forward-namespace argocd app create $app_name --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --sync-policy none --dest-namespace app_name --dest-server https://kubernetes.default.svc --directory-recurse; then
    echo "Failed to execute argocd command. Stopping execution."
    exit 1
  fi

  # Check if sleep interval needs to be applied
  if [ $((i % sleep_interval)) -eq 0 ]; then
    echo "Sleeping for 5 seconds..."
    sleep 5
  fi
done
