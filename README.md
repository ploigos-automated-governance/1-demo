# Overview

This repository provides the means to stand up and experiment with autoamted governance and piplines as a service using the Ploigos Everything workflow, OpenShift, OpenShift Pipeslines (Tekton), and OpenShift GitOps (ArgoCD).

There are four (4) large tasks to setup and run the demo:

1. First, Install the Ploigos Software Factory Platform
2. Second, Install the Ploigos Software Factory Pipeline & Demo Application
3. Thrid, Updated the Ploigos Software Factory Platform Configuration
4. Fourth, Expose the Pipeline as a Service, and Onboard the Demo Application

## Before You Start

Make sure the following components are installed on your local machine

- [OpenShift cli](https://docs.openshift.com/container-platform/4.7/cli_reference/openshift_cli/getting-started-cli.html) - Create applications and manage OpenShift Container Platform projects from a terminal
- [yqc cli](https://github.com/mikefarah/yq) - A lightweight and portable command-line YAML, JSON and XML processor

## Setup Instructions

To get started, clone this repository.  We will be mutating and adding files as part of the install instructions.  Either clone via SSH or HTTPS.

- Clone with SSH remote:

  ```shell
  git clone git@github.com:ploigos-automated-governance/demo-postinstall.git
  ```

- Clone with HTTPS remote:

  ```shell
  git clone https://github.com/ploigos-automated-governance/demo-postinstall.git
  ```

### First, Install the Ploigos Software Factory Platform

1. Create a `CatalogSource` to import the RedHatGov operator catalog.
```shell
oc apply -f - << EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: redhatgov-operators
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/redhatgov/operator-catalog:latest
  displayName: Red Hat NAPS Community Operators
  publisher: RedHatGov
EOF
```

1. Create a project for your pipeline tooling to live.
```shell
export PLOIGOS_PROJECT=devsecops
oc new-project $PLOIGOS_PROJECT
```

2. Delete any `LimitRange` that might have been created from project templates.
```shell
oc delete limitrange --all -n $PLOIGOS_PROJECT
```

3. Create a new `OperatorGroup` to support installation into the `$PLOIGOS_PROJECT` namespace:
```shell
oc apply -f - << EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  namespace: $PLOIGOS_PROJECT
  name: $PLOIGOS_PROJECT-og
spec:
  targetNamespaces:
    - $PLOIGOS_PROJECT
EOF
```

4. Install the Ploigos Software Factory Operator into the new namespace:
```shell
oc apply -f - << EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ploigos-software-factory-operator
  namespace: $PLOIGOS_PROJECT
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: ploigos-software-factory-operator
  source: redhatgov-operators
  sourceNamespace: openshift-marketplace
EOF
```

5. Create a PloigosPlatform.
```shell
oc create -f tekton-platform.yml
```

6. Resize the Nexus PVC to 100 GiB.
Use the OpenShift UI.
* Storage -> PersistentVolumeClaims -> Search for "nexus-sonatype-nexus-data" -> Select the pvc -> Actions -> Expand PVC
* 100 GiB
* Select "Expand"
* Restart the nexus pod: Pods -> Click the 3 dots icon next to "nexus-sonatype-nexus-..." -> Delete Pod
* Select "Delete"

7. Install Rekor
```shell
oc create -f https://raw.githubusercontent.com/ploigos/openshift-pipelines-quickstart/main/argo-cd-apps/app-of-apps/software-supply-chain-platform-ploigos-swf.yml
```

8. Expose a Rekor route
```shell
oc expose service rekor-server -n sigstore
```

### Second, Install the Ploigos Software Factory Pipeline & Demo Application

9. Install the everything pipeline using helm
```shell
git clone https://github.com/ploigos/ploigos-charts.git
cp values.yaml ploigos-charts/charts/ploigos-workflow/tekton-pipeline-everything/
pushd ploigos-charts/charts/ploigos-workflow/tekton-pipeline-everything/
helm install -f values.yaml everything-pipeline .

```

10. Fork the application code repository demo application
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

11. Fork the gitops repository for the demo application
* Continue using the Gitea UI. Use the same URL / username / password from the previous step.
* Navigate to the dashboard view (select "Dashboard" from the top menu).
* Create a new repository for the demo app's gitops repo in the "platform" organization
    * Organization (small tab on the right side of the screen) -> platform -> New Repository
    * Repository Name: `reference-quarkus-mvn-gitops`
      * **NOTE:** you have to either a) use this exact name for the repo, or b) update the file located at `cicd/ploigos-software-factory-operator/ploigos-step-runner-config/config.yml` in your fork of the app source code repository with whatever name you want to use.
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

### Thrid, Update the Ploigos Software Factory Platform Configuration

12. Export the Ploigos platform configuration.
```shell
oc get cm ploigos-platform-config-mvn -n devsecops -o yaml | yq > config.yml
oc get secret ploigos-platform-config-secrets-mvn -o yaml | yq | base64 -d > config-secrets.yml
```

13. Add Ploigos platform configuration for the generate-evidence step.
* Edit `config.yml` and add this to the bottom. Preserve the indentation (2 spaces).
```yaml
  generate-evidence:
  - name: Generate and Push Evidence
    implementer: GenerateEvidence
    config:
      evidence-destination-url: http://nexus-sonatype-nexus-service.devsecops.svc.cluster.local:8081/repository/workflow-evidence
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

14. Add Ploigos platform configuration for the audit-attestation step.
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

15. Update pgp private key for signing evidence
```shell
`PKEY=$(yq '.step-runner-config.sign-container-image[].config.container-image-signer-pgp-private-key' config-secrets.yml)
`yq -i ".step-runner-config.global-defaults.signer-pgp-private-key = \"$PKEY\"" config-secrets.yml`
```

16. Add Ploigos platform configuration for the container-image-static-compliance-scan step
* Edit `config.yml` and add this to the bottom. Preserve the indentation (2 spaces).
```yaml
  container-image-static-compliance-scan:
    - name: OpenSCAP - Compliance - SSG RHEL8
      implementer: OpenSCAP
      config:
        oscap-input-definitions-uri: https://raw.githubusercontent.com/RedHatGov/rhel8-stig-latest/master/ssg-rhel8-ds.xml
        oscap-tailoring-uri: https://raw.githubusercontent.com/ploigos/ploigos-example-oscap-content/main/xccdf_com.ploigos_profile_standard_compliance_ploigos_reference_apps-tailoring.xml
        oscap-profile: xccdf_com.ploigos_profile_standard_compliance_ploigos_reference_apps
```

17. Create a new ConfigMap and Secret with the updated Ploigos platform configuration.
```shell
oc create cm ploigos-platform-config-demo --from-file=config.yml -n devsecops
oc create secret generic ploigos-platform-config-secrets-demo --from-file config-secrets.yml -n devsecops
```

18. Test the pipeline with the new configuration.
```shell
oc create -f everything-pipelinerun.yml 
```

### Fourth, Expose the Pipeline as a Service, and Onboard the Demo Application

19. Create the k8s resources for a Pipeline as a Service (EventLister / TriggerTemplate / Route).
```shell
oc create -f el.yml
oc create -f tt.yml
oc expose svc el-everything-pipeline
```

21. Create webhook in gitea for demo app.
* In the the Gitea web open the *app source code* repo named reference-quarkus-mvn. (Not the -gitops repo.)
* The URL should be something like https://gitea-devsecops.apps.your.cluster.com/platform/reference-quarkus-mvn
* Settings (top right) -> Webhooks -> Add Webhook -> Gitea
* Target URL - Enter the URL for the Route you just created for the EventListener. You can get it with `echo "http://$(oc get route el-everything-pipeline -o yaml | yq .status.ingress[].host)/"` 
* Select "Add Webhook"

20. Test the webhook by editing the source code in the Gitea UI.
* In the Gitea UI browse to the reference-quarkus-mvn project
* Select "README.md"
* Select "Edit File" (pencil icon to the top right)
* Add some text to the file
* Select "Create a new branch ..." (scroll down)
* Name the branch `feature/demo`
* Select "Propose file change"
* In the OpenShift web UI you should see a running pipeline
  * Pipelines (tab in the left navigation) -> Pipelines
* The pipeline should finish successfully. This may take 15+ minutes.

21. Edit the yaml for the app1-service Pipeline. Under tasks:, for the task named ci-push-container-image-to-repository, in the taskRef: field, change name to ci-push-container-image-to-repository.

22.  Gitlab setup instructions
* Look up gitlab root credentials
	* The username is "root"
	* For the password, look in secret gitlab-gitlab-initial-root-password in namespace gitlab-system
* Look up gitlab URL
	* oc get route -n gitlab-system
	* It's the one that starts with "gitlab."
* Browse to that url and login using the gitlab root credentials
* New Project -> Create blank project
* Project name: reference-quarkus-mvn
* UNCHECK the checkbox for 'Initialize repository with a README'
* Select the button at the bottom to create the repo
* In Gitea, browse to the reference-quarkus-mvn project.
	* Example url: https://gitea-devsecops.apps.n4vqtd9t.usgovvirginia.aroapp.azure.us/platform/reference-quarkus-mvn
	* Copy the Clone URL (clipboard button, top right, between the text box that contains an https: url and the 'Download Repository' button)
* In the terminal, 
	* git clone <paste the url you just copied from gitea>
	* cd reference-quarkus-mvn/
	* git config http.sslVerify "false"
* In GitLab, on the page for the new project
	* Select the 'Clone' dropdown, Select the clipboard icon under 'Clone with HTTPS'
* In the terminal,
	* git remote set-url origin <paste the url you just copied from gitlab>
	* git push
	* Enter the gitlab root credentials
* Do all of that again for the project called reference-quarkus-mvn-gitops
* oc create -f gitlab-ctb.yml
* oc create -f gitlab-eventlistener.yml


## Troubleshooting
* To get the admin credentials for ArgoCD:
  * `oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.username | base64 -d && echo`
  * `oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.password | base64 -d && echo`
