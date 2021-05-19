#!bin/bash

gcloud container clusters get-credentials my-gke-cluster --zone europe-west1-b
kubectl create namespace airflow

kubectl create secret generic git-ssh-key --from-file=gitSshKey=/Users/osuarez/.ssh/id_rsa --namespace airflow
sudo kubectl create secret tls tls-cert --cert cert.pem --key privkey.pem --namespace airflow

# Get the instance IP from the resource with gcloud
# $(terraform output -json instance_SQL_ip_addr | jq -r '.[0].ip_address')

# Use the IP to create the secrets
kubectl create secret generic postgres-secrets --from-literal=connection="postgresql://airflow:airflow@$(terraform output -json instance_SQL_ip_addr | jq -r '.[0].ip_address'):5432/airflow?sslmode=disable" --namespace airflow
kubectl create secret generic result-backend-secrets --from-literal=connection="db+postgresql://airflow:airflow@$(terraform output -json instance_SQL_ip_addr | jq -r '.[0].ip_address'):5432/airflow?sslmode=disable" --namespace airflow
kubectl create secret generic google-cloud-key --from-file=key.json=./service_account.json --namespace airflow

# Set the correct bucket for remote logging
BUCKET=$(terraform output remote_logging_bucket | jq -r)
OLD_BUCKET_NAME=$(awk '/AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER/{getline; print}' ./airflow-master/chart/values.yaml | grep -o "'.*'" | sed "s/'//g")
sed -i 's|'"$OLD_BUCKET_NAME"'|'"$BUCKET"'|g' ./airflow-master/chart/values.yaml

# install first the KEDA application
kubectl create namespace keda

helm install keda kedacore/keda --namespace keda --version "v2.0.0"

# Wait for the KEDA pods to be ready
kubectl wait deployments --all --for condition=ready --namespace keda

helm install airflow ./airflow-master/chart --namespace airflow

