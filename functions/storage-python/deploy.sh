#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

gcloud functions deploy functions-storage-python \
  --project $PROJECT_ID \
  --region asia-northeast1 \
  --runtime python37 \
  --trigger-http \
  --entry-point main \
  --allow-unauthenticated \
  --service-account $SERVICE_ACCOUNT \
  --set-env-vars BUCKET_NAME=$BUCKET_NAME
