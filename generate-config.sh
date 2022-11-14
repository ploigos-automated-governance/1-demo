#!/bin/bash
set -ex -o pipefail

# Generate new configmap
oc get cm ploigos-platform-config-mvn -n devsecops -o yaml | yq '.data[]' > config.yml
REKOR_SERVER_URL=$(echo "https://$(oc get route rekor-server-route -n sigstore -o yaml | yq '.status.ingress[].host')/") envsubst < ./config-additions.yml >> config.yml

# Generate new secret
oc get secret ploigos-platform-config-secrets-mvn -n devsecops -o yaml | yq '.data[]' | base64 -d > config-secrets.yml
PKEY=$(yq '.step-runner-config.sign-container-image[].config.container-image-signer-pgp-private-key' config-secrets.yml)
yq -i ".step-runner-config.global-defaults.signer-pgp-private-key = \"$PKEY\"" config-secrets.yml
cat config-secrets-additions.yml >> config-secrets.yml
yq -i e '.step-runner-config.generate-evidence[0].config.evidence-destination-password = .step-runner-config.report[0].config.results-archive-destination-password' config-secrets.yml

# Fails if the cm or secret already exist. If you are sure you want to overwrite the cm/secret, delete them both before running this script.
oc create cm ploigos-platform-config-demo --from-file=config.yml -n devsecops
oc create secret generic ploigos-platform-config-secrets-demo --from-file config-secrets.yml -n devsecops

