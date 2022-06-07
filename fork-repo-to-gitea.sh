#!/usr/bin/bash
set -ex -o pipefail

GITEA_USER=ploigos
GITEA_PASS=$(oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.password | base64 -d)
REPO_NAME=${1}
SOURCE_URL=${2}

GITEA_NAMESPACE=devsecops
GITEA_URL="https://$(oc get route gitea -n ${GITEA_NAMESPACE} -o yaml | yq '.status.ingress[].host')"

GITEA_API_URL=${GITEA_URL}/api/v1

# Get an authentication token for the Gitea REST API
TOKEN_NAME=$(date +%s%N) # nanoseconds since epoch, to make it unique between executions
TOKEN_RESPONSE=$(curl -k -XPOST -H "Content-Type: application/json"  -k -d "{\"name\":\"${TOKEN_NAME}\"}" -u ${GITEA_USER}:${GITEA_PASS} ${GITEA_API_URL}/users/${GITEA_USER}/tokens)
TOKEN=$(echo ${TOKEN_RESPONSE} | yq e .sha1)

# Get the id of the Gitea organization that the new repo will belong to
TARGET_ORG=platform
ORG_ID=$( \
  curl -k 'GET' \
  "${GITEA_API_URL}/orgs/${TARGET_ORG}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "Authorization: token ${TOKEN}" \
  | yq e .id
)

# Fork the upstream repo into Gitea
curl -k -X 'POST' \
  "${GITEA_API_URL}/repos/migrate" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "Authorization: token ${TOKEN}" \
  -d "{
            \"clone_addr\": \"${SOURCE_URL}\", \
            \"uid\": ${ORG_ID}, \
            \"repo_name\": \"${REPO_NAME}\" \
     }"

