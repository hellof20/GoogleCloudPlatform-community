#!/bin/bash

set -e

PROJECT_ID=$project_id
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(project_number)")
GCF_SERVICE_ACCOUNT_NAME="resource-labeler-sa"
GCF_SERVICE_ACCOUNT="${GCF_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
TOPIC_NAME="asset-changes"
ASSET_TYPES="compute.googleapis.com/Instance,container.googleapis.com/Cluster,sqladmin.googleapis.com/Instance,storage.googleapis.com/Bucket"
PERMISSIONS="compute.instances.get,compute.instances.setLabels,container.clusters.get,container.clusters.update,storage.buckets.get,storage.buckets.update,cloudsql.instances.get,cloudsql.instances.update"

# create service account for cloud function
if [[ $(gcloud iam service-accounts list --filter "${GCF_SERVICE_ACCOUNT_NAME}" --format json | jq '.[]|has("name")') ]]; then
    echo "sa existed";
else
    gcloud iam service-accounts create "${GCF_SERVICE_ACCOUNT_NAME}" --project ${PROJECT_ID}
fi

# assign permissons to the service account
if [[ $(gcloud iam roles list --organization=${ORGANIZATION_ID} --filter ResourceLabelerRole --format json | jq '.[]|has("name")') ]]; then
    echo "iam role existed";
else
    gcloud iam roles create ResourceLabelerRole --organization=${ORGANIZATION_ID} --title "Resource Labeler Role" --permissions "${PERMISSIONS}" --stage GA
    # iam policy binding
    gcloud organizations add-iam-policy-binding ${ORGANIZATION_ID} \
        --member="serviceAccount:${GCF_SERVICE_ACCOUNT}" \
        --role="organizations/${ORGANIZATION_ID}/roles/ResourceLabelerRole"    
fi

# enable services
gcloud services enable cloudasset.googleapis.com pubsub.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com --project ${PROJECT_ID}
gcloud services enable compute.googleapis.com container.googleapis.com storage.googleapis.com sqladmin.googleapis.com --project ${PROJECT_ID}

# create pubsub topic
if [[ $(gcloud pubsub topics list --project ${PROJECT_ID} --filter "${TOPIC_NAME}" --format json | jq '.[]|has("name")') ]]; then
    echo "pubsub topic existed";
else
    gcloud pubsub topics create "${TOPIC_NAME}" --project ${PROJECT_ID}
fi

gcloud beta services identity create --service=cloudasset.googleapis.com --project=${PROJECT_ID}
gcloud pubsub topics add-iam-policy-binding "${TOPIC_NAME}" --member "serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-cloudasset.iam.gserviceaccount.com" \
     --role roles/pubsub.publisher --project ${PROJECT_ID}

gcloud asset feeds list --organization ${ORGANIZATION_ID} --format="flattened(feeds[].name)" --billing-project ${PROJECT_ID} | grep -q "feed-resources-${ORGANIZATION_ID}"
if [ $? -ne 0 ] ;then
    gcloud asset feeds create "feed-resources-${ORGANIZATION_ID}" --organization="${ORGANIZATION_ID}" \
    --content-type=resource --asset-types="${ASSET_TYPES}" \
    --pubsub-topic="projects/${PROJECT_ID}/topics/${TOPIC_NAME}" \
    --billing-project ${PROJECT_ID}
else
    echo "feed existed"
fi

cd cloud-function-auto-resource-labeler
if [[ $(gcloud functions list --project ${PROJECT_ID} --filter auto_resource_labeler --format json | jq '.[]|has("name")') ]]; then
    echo 'function existed'
else
    gcloud functions deploy auto_resource_labeler --runtime python38 \
    --trigger-topic "${TOPIC_NAME}" \
    --service-account="${GCF_SERVICE_ACCOUNT}" \
    --project ${PROJECT_ID}
fi
echo "Deploy finished."    
