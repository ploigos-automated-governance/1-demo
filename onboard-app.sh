#!/usr/bin/bash
set -ex -o pipefail

GITEA_APP_REPO=${1}

GITEA_ORG=platform
GITEA_NAMESPACE=devsecops

GITEA_USER=$(oc get secret gitea-admin-credentials -o yaml | yq .data.username | base64 -d)
GITEA_PASS=$(oc get secret gitea-admin-credentials -o yaml | yq .data.password | base64 -d)
GITEA_URL="https://$(oc get route gitea -n ${GITEA_NAMESPACE} -o yaml | yq '.status.ingress[].host')"
GITEA_API_URL=${GITEA_URL}/api/v1
EVENT_LISTENER_URL="http://$(oc get route el-everything-pipeline -o yaml | yq .status.ingress[].host)/"


# Get an authentication token for the Gitea REST API
TOKEN_NAME=$(date +%s%N) # nanoseconds since epoch, to make it unique between executions
TOKEN_RESPONSE=$(curl -k -XPOST -H "Content-Type: application/json"  -k -d "{\"name\":\"${TOKEN_NAME}\"}" -u ${GITEA_USER}:${GITEA_PASS} ${GITEA_API_URL}/users/${GITEA_USER}/tokens)
TOKEN=$(echo ${TOKEN_RESPONSE} | yq e .sha1)

# Create a Gitea webhook to trigger the Tekton pipeline when the demo application code changes
curl -k \
"${GITEA_API_URL}/repos/${GITEA_ORG}/${GITEA_APP_REPO}/hooks" \
-H 'accept: application/json' \
-H 'Content-Type: application/json' \
-H "Authorization: token ${TOKEN}" \
-d "{ \
  \"type\": \"gitea\", \
  \"active\": true, \
  \"config\": {\"content_type\": \"json\", \"url\": \"${EVENT_LISTENER_URL}\"} \
}"

