#!/bin/bash

# Check if both parameters are provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <num_of_apps>"
  exit 1
fi

iterations=$1
# Iterate and execute the argocd command
for ((i=1; i<=iterations; i++))
do
  # Set app name
  app_number=$(printf "%06d" $i)
  app_name=guestbook$app_number

  # Execute the argocd command
  echo "Deleting app: $app_name"
  if ! argocd app delete $app_name -y; then
    echo "Failed to execute argocd command. Stopping execution."
    exit 1
  fi

done
