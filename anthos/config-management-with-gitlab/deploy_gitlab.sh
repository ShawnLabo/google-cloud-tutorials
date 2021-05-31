#!/usr/bin/env bash

# ref. https://cloud.google.com/architecture/deploying-production-ready-gitlab-on-gke

set nounset
set errexit
set pipefail

project_id=$(gcloud config get-value project)

read -r -p "Deploying GitLab into ${project_id}. Are you sure? [y/N] " yn

if [[ "$yn" != "y" ]] && [[ "$yn" != "Y" ]]; then
  echo "canceled"
  exit
fi


gcloud services enable \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com \
  redis.googleapis.com \
  sqladmin.googleapis.com

gcloud compute addresses create gitlab --global


# Storage

gcloud iam service-accounts create gitlab-gcs
gcloud projects add-iam-policy-binding $project_id \
  --role roles/storage.admin \
  --member serviceAccount:gitlab-gcs@${project_id}.iam.gserviceaccount.com

gsutil mb -l ASIA-NORTHEAST1 gs://${project_id}-gitlab-backups
gsutil mb -l ASIA-NORTHEAST1 gs://${project_id}-git-lfs
gsutil mb -l ASIA-NORTHEAST1 gs://${project_id}-gitlab-artifacts
gsutil mb -l ASIA-NORTHEAST1 gs://${project_id}-gitlab-uploads
gsutil mb -l ASIA-NORTHEAST1 gs://${project_id}-gitlab-packages
gsutil mb -l ASIA-NORTHEAST1 gs://${project_id}-gitlab-pseudo
gsutil mb -l ASIA-NORTHEAST1 gs://${project_id}-runner-cache
gsutil mb -l ASIA-NORTHEAST1 gs://${project_id}-registry


# SQL

gcloud compute addresses create gitlab-sql \
  --global \
  --prefix-length 20 \
  --network default
gcloud services vpc-peerings connect \
  --service servicenetworking.googleapis.com \
  --ranges gitlab-sql \
  --network default

gcloud beta sql instances create gitlab-db \
  --network default \
  --database-version POSTGRES_12 \
  --cpu 4 \
  --memory 15 \
  --no-assign-ip \
  --storage-auto-increase \
  --zone asia-northeast1-a

password=$(openssl rand -base64 18)

gcloud sql users create gitlab --instance gitlab-db --password "$password"
gcloud sql databases create --instance gitlab-db gitlabhq_production


# Redis

gcloud redis instances create gitlab \
  --size 2 \
  --region asia-northeast1 \
  --zone asia-northeast1-a \
  --tier standard


# GKE

gcloud container clusters create gitlab \
  --machine-type e2-standard-8 \
  --zone asia-northeast1-a \
  --enable-ip-alias

gcloud container clusters get-credentials gitlab \
  --zone asia-northeast1-a

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: pd-ssd
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
EOF

kubectl create secret generic gitlab-pg --from-literal=password="${password}"

gcloud iam service-accounts keys create \
  --iam-account gitlab-gcs@${project_id}.iam.gserviceaccount.com /tmp/${project_id}-gcs-key.json
kubectl create secret generic google-application-credentials \
  --from-file=gcs-application-credentials-file="/tmp/${project_id}-gcs-key.json"

cat <<EOF > /tmp/${project_id}-rails.yaml
provider: Google
google_project: $project_id
google_client_email: gitlab-gcs@${project_id}.iam.gserviceaccount.com
google_json_key_string: '$(cat /tmp/${project_id}-gcs-key.json)'
EOF
kubectl create secret generic gitlab-rails-storage --from-file=connection="/tmp/${project_id}-rails.yaml"

cat <<EOF > /tmp/${project_id}-registry.gcs.yaml
gcs:
  bucket: ${project_id}-gitlab-registry-storage
  keyfile: /etc/docker/registry/storage/gcs.json
EOF
kubectl create secret generic gitlab-registry-storage \
  --from-file=storage=/tmp/${project_id}-registry.gcs.yaml \
  --from-file=gcs.json=/tmp/${project_id}-gcs-key.json


# GitLab

curl -sL -o /tmp/${project_id}-values.yaml.tpl \
  https://raw.githubusercontent.com/ShawnLabo/google-cloud-tutorials/main/anthos/config-management-with-gitlab/gitlab-values.yaml.tpl
curl -sL -o /tmp/${project_id}-ingress.yaml \
  https://raw.githubusercontent.com/ShawnLabo/google-cloud-tutorials/main/anthos/config-management-with-gitlab/gitlab-ingress.yaml

export PROJECT_ID=$project_id
export INGRESS_IP=$(gcloud compute addresses describe gitlab --global --format 'value(address)')
export DOMAIN=gitlab.${INGRESS_IP}.nip.io
export DB_PRIVATE_IP=$(gcloud sql instances describe gitlab-db --format 'value(ipAddresses[0].ipAddress)')
export REDIS_PRIVATE_IP=$(gcloud redis instances describe gitlab --region asia-northeast1 --format 'value(host)')

cat > /tmp/${project_id}-managed-certificate.yaml <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: gitlab-certificate
spec:
  domains:
    - ${DOMAIN}
EOF
kubectl apply -f /tmp/${project_id}-managed-certificate.yaml

< /tmp/${project_id}-values.yaml.tpl envsubst > /tmp/${project_id}-values.yaml

helm repo add gitlab https://charts.gitlab.io/
helm install -f /tmp/${project_id}-values.yaml gitlab gitlab/gitlab

kubectl delete ingress gitlab-webservice-default
kubectl apply -f /tmp/${project_id}-ingress.yaml

password=$(kubectl get secret gitlab-gitlab-initial-root-password -o go-template='{{.data.password}}' | base64 -d)

echo "********"
echo "Fix healthcheck, then..."
echo "Your GitLab URL is: https://${DOMAIN}"
echo "Root password is: ${password}"
echo "********"


# Clean up

rm -f /tmp/${project_id}-{gcs-key.json,rails.yaml,registry.gcs.yaml,ingress.yaml,values.yaml.tpl,managed-certificate.yaml}
