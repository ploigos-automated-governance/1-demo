#!/bin/bash
set -eux -o pipefail

#########################################################################################################################
# WARNING!!! This script prints out details of the installed environment, including passwords. Please use it carefully. #
#########################################################################################################################

# Script configuration
VERBOSE=false # Set to "true" to have this script output debug information including the commands it is running.
# ** Also see the configuration under ./2-platform-ops/install-platform.sh, which is downloaded the first tim eyou run this script. It has ts own VERBOSE setting.

# Do not change
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PLATFORM_OPS_DIR=${SCRIPT_DIR}/2-platform-ops

if [ "${VERBOSE}" == "true" ]; then set +x; fi

# Clone the platform-ops repository if it has not already been cloned
[ ! -d ${PLATFORM_OPS_DIR} ] && git clone https://github.com/ploigos-automated-governance/1-demo.git ${PLATFORM_OPS_DIR}

# Run the platform-ops install script
${PLATFORM_OPS_DIR}/install-platform.sh

# Print environment details
SERVICE_USER=ploigos
SERVICE_PASS=$(oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.password | base64 -d)
ARGOCD_URL=$(echo "http://$(oc get route argocd-server -n devsecops -o yaml | yq .status.ingress[].host)/")
GITEA_URL=$(echo "http://$(oc get route gitea -n devsecops -o yaml | yq .status.ingress[].host)/")
set +x
echo
echo "Installation Successful!"
echo
echo "=== Environment Details ==="
echo
echo "--- ArgoCD ---"
echo "URL: ${ARGOCD_URL}"
echo "Username: ${SERVICE_USER}"
echo "Password: ${SERVICE_PASS}"
echo
echo "--- Gitea ---"
echo "URL: ${GITEA_URL}"
echo "Username: ${SERVICE_USER}"
echo "Password: ${SERVICE_PASS}"
set -x

