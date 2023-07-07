#!/bin/bash

# Check if both parameters are provided
if [ $# -ne 3 ]; then
  echo "Usage: $0 <start> <stop> <batch_interval>"
  exit 1
fi

if [[ -z "$ARGOCD_LOGIN_SERVER" ]] || [[ -z "$ARGOCD_PASSWORD" ]]; then
  echo "Error: ARGOCD_LOGIN_SERVER and ARGOCD_PASSWORD must be set."
  exit 1
fi

start=$1
stop=$2
batch_interval=$3

# login to argocd server
echo "start: $start"
echo "stop: $stop"
echo "batch_interval: $batch_interval"
echo "ARGOCD_LOGIN_SERVER: $ARGOCD_LOGIN_SERVER"

argocd login $ARGOCD_LOGIN_SERVER --username admin --password $ARGOCD_PASSWORD --insecure

# Iterate and execute the argocd command
for ((i=start; i<=stop; i++))
do
  # Set app name
  app_number=$(printf "%06d" $i)
  app_name=guestbook$app_number

  # Execute the argocd command
  echo "Deploying app: $app_name"

  retry_count=0
  max_retries=5

  while ((retry_count < max_retries))
  do
    output=$(argocd app create $app_name --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --sync-policy none --sync-option CreateNamespace=true --dest-namespace $app_name --dest-server https://kubernetes.default.svc --directory-recurse --upsert -l testing=argoperf 2>&1)

    if [ $? -eq 0 ]; then
      echo "$output"
      break
    else
      retry_count=$((retry_count + 1))
      echo "Failed to execute argocd command. Attempt: $retry_count"
      echo "$output"
      sleep 5
    fi

    # If we've reached the max number of retries, exit with failure.
    if ((retry_count == max_retries)); then
      echo "Failed to execute argocd command after $max_retries attempts. Stopping execution."
      exit 1
    fi
  done

  # Check if sleep interval needs to be applied based on batch interval
  if [ $((i % batch_interval)) -eq 0 ]; then
    echo "Sleeping for 5 seconds..."
    sleep 5
  fi
done
