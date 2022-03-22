# Setup Instructions

1. Install the Ploigos Software Factory Operator. Follow steps 1-5 of the [Operator README quickstart instructions](https://github.com/ploigos/ploigos-software-factory-operator/#quick-start). **STOP AFTER STEP #5.**

2. Create a PloigosPlatform.
```shell
oc create -f tekton-platform.yml```
```
**WE STOPPED HERE IN THE ARO CLUSTER**

3. Resize the Nexus PVC to 100 GiB.
Use the OpenShift UI.
* Storage -> PersistentVolumeClaims -> Search for "nexus-sonatype-nexus-data" -> Select the pvc -> Actions -> Expand PVC
* 100 GiB
* Select "Expand"
* Restart the nexus pod: Pods -> Click the 3 dots icon next to "nexus-sonatype-nexus-..." -> Delete Pod
* Select "Delete"

5. Install Rekor
```shell
oc create -f https://raw.githubusercontent.com/ploigos/openshift-pipelines-quickstart/main/argo-cd-apps/app-of-apps/software-supply-chain-platform-ploigos-swf.yml
```

6. Expose a Rekor route
```shell
oc expose service rekor-server -n sigstore
```
7. Install the everything pipeline using helm
```shell
git clone https://github.com/ploigos/ploigos-charts.git
cp values.yaml ploigos-charts/charts/ploigos-workflow/tekton-pipeline-everything/
pushd ploigos-charts/charts/ploigos-workflow/tekton-pipeline-everything/
helm install -f values.yaml everything-pipeline .

```

8. Fork the application code repository demo application
* Look up the Gitea URL
  * `oc get route gitea -o yaml | yq .status.ingress[].host`
* Look up the Gitea username
  * `oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.username | base64 -d && echo`
* Look up the Gitea password
  * `oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.password | base64 -d && echo`
* Using the above URL / username / password, log into Gitea using your browser.
* Create a new repository for the demo app in the "platform" organization
  * Organization (small tab on the right side of the screen) -> platform -> New Repository
  * Repository Name: `reference-quarkus-mvn`
  * Select "Create Repository"
  * Select the clipboard icon to copy the HTTPS clone URL
  * Save that URL but don't use it yet
* Clone the upstream repository for the demo app
  * `git clone https://github.com/ploigos-automated-governance/reference-quarkus-mvn.git`
  * `cd reference-quarkus-mvn`
* Change the "origin" remote of the local git repo you just cloned to point at the Gitea URL you (hopefully) saved
  * `git remote set-url origin <<YOUR URL>>`
* Push the upstream code to the new repo that you created in Gitea
  * `git push`
  * Enter the username and password from above
  * `cd ..`

9. Fork the gitops repository for the demo application
* Continue using the Gitea UI. Use the same URL / username / password from the previous step.
* Navigate to the dashboard view (select "Dashboard" from the top menu).
* Create a new repository for the demo app's gitops repo in the "platform" organization
    * Organization (small tab on the right side of the screen) -> platform -> New Repository
    * Repository Name: `reference-quarkus-mvn-gitops`
    * Select "Create Repository"
    * Select the clipboard icon to copy the HTTPS clone URL
    * Save that URL but don't use it yet
* Clone the upstream gitops repository for the demo app
    * `git clone https://github.com/ploigos-automated-governance/reference-quarkus-mvn-gitops.git`
    * `cd reference-quarkus-mvn-cloud-resources_tekton_workflow-everything`
* Change the "origin" remote of the local git repo you just cloned to point at the Gitea URL you (hopefully) saved
    * `git remote set-url origin <<YOUR URL>>`
* Push the upstream code to the new repo that you created in Gitea
    * `git push`
    * Enter the username and password from above if prompted
  * `cd ..`

10. Export the Ploigos platform configuration.
```shell
oc get cm ploigos-platform-config-mvn -n devsecops -o yaml | yq .data[] > config.yml
oc get secret ploigos-platform-config-secrets-mvn -o yaml | yq .data[] | base64 -d > config-secrets.yml
```

11. Add Ploigos platform configuration for the generate-evidence step.
* Edit `config.yml` and add this to the bottom. Preserve the indentation (2 spaces).
```yaml
  generate-evidence:
  - name: Generate and Push Evidence
    implementer: GenerateEvidence
    config:
      evidence-destination-url: http://nexus-sonatype-nexus-service.devsecops.svc.cluster.local:8081/repository/release-engineering-workflow-evidence/
      evidence-destination-username: ploigos
  - name: Sign Evidence
    implementer: RekorSignEvidence
    config:
      rekor-server-url: REKOR_SERVER_URL
```
* Replace `REKOR_SERVER_URL` with the output of `echo "https://$(oc get route rekor-server -n sigstore -o yaml | yq '.status.ingress[].host')/"`
* Save `config.yml`.
* Edit `config-secrets.yml` and add this to the bottom. Preserve the indentation (2 spaces).
```yaml
  generate-evidence:
  - name: Generate and Push Evidence
    implementer: GenerateEvidence
    config:
      evidence-destination-password: EVIDENCE_DESTINATION_PASSWORD
```
* Replace `EVIDENCE_DESTINATION_PASSWORD` with the value of `results-archive-destination-password`. This value should be on the last line of the file before you added the generate-evidence snippet.
* Save `config-secrets.yml`.

12. Add Ploigos platform configuration for the audit-attestation step.
* Edit `config.yml` and add this to the bottom. Preserve the indentation (2 spaces).
```yaml
  audit-attestation:
  - name: Audit Attestation DEV
    implementer: OpenPolicyAgent
    environment-config:
      DEV:
        workflow-policy-uri: https://raw.githubusercontent.com/ploigos/ploigos-example-autogov-content/main/workflow-policy-dev.rego
      TEST:
        workflow-policy-uri: https://raw.githubusercontent.com/ploigos/ploigos-example-autogov-content/main/workflow-policy-test.rego
      PROD:
        workflow-policy-uri: https://raw.githubusercontent.com/ploigos/ploigos-example-autogov-content/main/workflow-policy-prod.rego
```

12. Update pgp private key for signing evidence
```shell
`PKEY=$(yq '.step-runner-config.sign-container-image[].config.container-image-signer-pgp-private-key' config-secrets.yml)
`yq -i ".step-runner-config.global-defaults.signer-pgp-private-key = \"$PKEY\"" config-secrets.yml`
```

13. Update Rekor url in ConfigMap
```shell
oc get cm -o yaml ploigos-platform-config-hack > ploigos-platform-config-hack.yml
```
Edit the file and replace:
```yaml
          rekor-server-url: https://rekor.apps.tssc.rht-set.com/
```
with:
```yaml
          rekor-server-url: https://[[[hostname from above]]]/
```
```shell
oc apply -f ploigos-platform-config-hack.yml
```

14. Apply the changes to the Ploigos platform configuration
```shell
oc create secret generic ploigos-platform-config-secrets-hack --from-file /tmp/platform-config-secret.yml
```

16. Create webhook in gitea for demo app
* Settings -> Webhooks -> Add Webhook
* Payload URL - Enter the Tekton EventListener webhook URL for your cluster.
* Content Type: `application/json`
* SSL Verification - `false`

16. Login to gitea and create a PR


# Troubleshooting
* To get the admin credentials for ArgoCD:
  * `oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.username | base64 -d && echo`
  * `oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.password | base64 -d && echo`
