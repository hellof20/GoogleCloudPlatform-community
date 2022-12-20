#!/bin/bash

set -e

PROJECT_ID=$project_id
TOPIC_NAME="asset-changes"
GCF_SERVICE_ACCOUNT_NAME="resource-labeler-sa"
GCF_SERVICE_ACCOUNT="${GCF_SERVICE_ACCOUNT_NAME}@${project_id}.iam.gserviceaccount.com"

#delete feed
if gcloud asset feeds list --organization ${ORGANIZATION_ID} --format="flattened(feeds[].name)" --billing-project ${PROJECT_ID} | grep -q "feed-resources-${ORGANIZATION_ID}";then
    gcloud asset feeds delete feed-resources-${ORGANIZATION_ID} --organization ${ORGANIZATION_ID} --quiet
else
    echo "feed feed-resources-${ORGANIZATION_ID} not existed"
fi

# delete function
if [[ $(gcloud functions list --project ${PROJECT_ID} --filter auto_resource_labeler --format json | jq '.[]|has("name")') ]]; then
    gcloud functions delete auto_resource_labeler --project ${project_id} --quiet
else
    echo 'function not existed'
fi

# delete topic
if [[ $(gcloud pubsub topics list --project ${PROJECT_ID} --filter "${TOPIC_NAME}" --format json | jq '.[]|has("name")') ]]; then
    gcloud pubsub topics delete ${TOPIC_NAME} --project ${project_id} --quiet
else
    echo "pubsub topic not existed";
fi

# delete service account
if [[ $(gcloud iam service-accounts list --filter "${GCF_SERVICE_ACCOUNT_NAME}" --format json | jq '.[]|has("name")') ]]; then
    gcloud iam service-accounts delete ${GCF_SERVICE_ACCOUNT} --project ${project_id} --quiet
else
    echo "sa not existed";
fi

echo "Destroy finished!"
