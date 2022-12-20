#!/bin/bash

fail() {
    echo "$@"
    exit 1
}

PROJECT_ID=$project_id
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(project_number)")
GCF_SERVICE_ACCOUNT_NAME="resource-labeler-sa"
GCF_SERVICE_ACCOUNT="${GCF_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
TOPIC_NAME="asset-changes"
ASSET_TYPES="compute.googleapis.com/Instance,container.googleapis.com/Cluster,sqladmin.googleapis.com/Instance,storage.googleapis.com/Bucket"

gcloud iam service-accounts create "${GCF_SERVICE_ACCOUNT_NAME}" --project ${PROJECT_ID}

PERMISSIONS="compute.instances.get,compute.instances.setLabels,container.clusters.get,container.clusters.update,storage.buckets.get,storage.buckets.update,cloudsql.instances.get,cloudsql.instances.update"
gcloud iam roles create ResourceLabelerRole --organization=${ORGANIZATION_ID} --title "Resource Labeler Role" --permissions "${PERMISSIONS}" --stage GA

MEMBER="user:$(gcloud config get-value account)"
gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} --member="${MEMBER}" --role="roles/cloudasset.owner"
gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} --member="serviceAccount:${GCF_SERVICE_ACCOUNT}" --role="organizations/${ORGANIZATION_ID}/roles/ResourceLabelerRole"

gcloud services enable cloudasset.googleapis.com pubsub.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com --project ${PROJECT_ID}
gcloud services enable compute.googleapis.com container.googleapis.com storage.googleapis.com sqladmin.googleapis.com --project ${PROJECT_ID}


gcloud pubsub topics create "${TOPIC_NAME}" --project ${PROJECT_ID}
gcloud beta services identity create --service=cloudasset.googleapis.com --project=${PROJECT_ID}
gcloud pubsub topics add-iam-policy-binding "${TOPIC_NAME}" --member "serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-cloudasset.iam.gserviceaccount.com" \
    --role roles/pubsub.publisher --project ${PROJECT_ID}

gcloud asset feeds create "feed-resources-${ORGANIZATION_ID}" --organization="${ORGANIZATION_ID}" \
    --content-type=resource --asset-types="${ASSET_TYPES}" \
    --pubsub-topic="projects/${PROJECT_ID}/topics/${TOPIC_NAME}" \
    --billing-project ${PROJECT_ID}

cd cloud-function-auto-resource-labeler
gcloud functions deploy auto_resource_labeler --runtime python38 \
    --trigger-topic "${TOPIC_NAME}" \
    --service-account="${GCF_SERVICE_ACCOUNT}" \
    --project ${PROJECT_ID}
    
echo "Deploy finished."    
