#!/bin/bash

fail() {
    echo "$@"
    exit 1
}

TOPIC_NAME="asset-changes"
GCF_SERVICE_ACCOUNT_NAME="resource-labeler-sa"
GCF_SERVICE_ACCOUNT="${GCF_SERVICE_ACCOUNT_NAME}@${project_id}.iam.gserviceaccount.com"

gcloud asset feeds delete feed-resources-${ORGANIZATION_ID} --organization ${ORGANIZATION_ID} --quiet
gcloud functions delete auto_resource_labeler --project ${project_id} --quiet
gcloud pubsub topics delete ${TOPIC_NAME} --project ${project_id} --quiet
gcloud iam service-accounts delete ${GCF_SERVICE_ACCOUNT} --project ${project_id} --quiet
gcloud iam roles delete ResourceLabelerRole --organization=${ORGANIZATION_ID} --quiet
