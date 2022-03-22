# Post-Install Instructions

1. Install the Ploigos Software Factory Operator. Do steps 1-5 of the [Operator README quickstart instructions](https://github.com/ploigos/ploigos-software-factory-operator/#quick-start). **STOP AFTER STEP #5.**

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

11. Install the everything pipeline using helm
```shell
git clone https://github.com/ploigos/ploigos-charts.git
cp values.yaml ploigos-charts/charts/ploigos-workflow/tekton-pipeline-everything/
pushd ploigos-charts/charts/ploigos-workflow/tekton-pipeline-everything/
helm install -f values.yaml everything-pipeline .

```

13. Change default image to ploigos-tool-maven in TriggerTemplate
oc get tt ploigos-workflow-ref-quarkus-mvn-fruit -o yaml > tt.yml
vi tt.yml 
       - name: workflowWorkerImageDefault
         value: quay.io/ploigos/ploigos-tool-maven:latest
oc create ...

14. Get gitea admin user
oc get secret gitea-admin-credentials -o yaml # get password
echo -n [whatever] | base64 -d # decode password
oc get route gitea

15. Clone demo app
git clone https://gitea-devsecops.apps.cluster-fd74.fd74.sandbox195.opentlc.com/platform/reference-quarkus-mvn.git
git checkout -b feature/demo
git push --set-upstream origin feature/demo

16. Login to gitea and create a PR

17. Create webhook in gitea for demo app
settings -> webhooks -> just like github

18. Update configmap and secret with new config for generate-evidence

 generate-evidence:
  - name: Generate and Push Evidence
    implementer: GenerateEvidence
    config:
      evidence-destination-url: https://nexus.apps.tssc.rht-set.com/repository/release-engineering-workflow-evidence/
      evidence-destination-username: sa-ploigos-ref-apps
  - name: Sign Evidence
    implementer: RekorSignEvidence
    config:
      rekor-server-url: https://rekor.apps.tssc.rht-set.com/

    generate-evidence:
    -   name: Generate and Push Evidence
        implementer: GenerateEvidence
        config:
            evidence-destination-password: [whatever]


1. Update configmap and secret with new config for audit-attestation

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
  
1. Update pgp private key for signing evidence
PKEY=$(sops -d ~/ploigos/demo/reference-quarkus-mvn/cicd/ploigos-integration-environment/tekton/everything/ploigos-step-runner-config/shared-config/config-secrets.yml  | yq .step-runner-config.global-defaults.signer-pgp-private-key)
cat platform-config-secret.yml | yq ".step-runner-config.global-defaults.signer-pgp-private-key = \"$PKEY\"" > /tmp/platform-config-secret.yml
oc create secret generic ploigos-platform-config-secrets-hack --from-file /tmp/platform-config-secret.yml


1. Remove ConfigLint step implementer from checked-in config.yml
```shell
yq -i 'del(.step-runner-config.validate-environment-configuration)' cicd/ploigos-software-factory-operator/ploigos-step-runner-config/config.yml
git commit -am "Remove ConfigLint StepImplementer"
git push
```

2. Expose a Rekor route
   **TODO:** turn pruning back on for rekor application when we no longer have to do this manually.
```shell
oc expose service rekor-server -n sigstore
oc get route rekor-server -n sigstore
```

1. Update Rekor url in ConfigMap
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

== Troubleshooting
1. To get the admin credentials for ArgoCD:
* `oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.username | base64 -d && echo`
* `oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.password | base64 -d && echo`
