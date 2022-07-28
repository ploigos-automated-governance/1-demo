# Overview

This repository provides the means to stand up and experiment with automated governance and pipelines as a service using the Ploigos Everything workflow, OpenShift, OpenShift Pipelines (Tekton), and OpenShift GitOps (ArgoCD).

There are four (4) large tasks to setup and run the demo:

1. First    - Install all the automated governance tools & systems 
    1. Ploigos Software Factory Operator
    2. `PloigosPlatform`
2. Second   - Install the Ploigos Pipeline, and the demo application
3. Third    - Update the Ploigos Platform configuration
4. Fourth   - Expose the Pipeline as a Service, and onboard the demo application

## Before You Start

Make sure the following components are installed on your local machine, or as part the environment you are working on.

- [git](https://git-scm.com/) - A free and open source distributed version control system designed to handle everything from small to very large projects with speed and efficiency.
- [yq cli](https://github.com/mikefarah/yq) (version 4 or greater) - A lightweight and portable command-line YAML, JSON and XML processor.
- [OpenShift cli](https://docs.openshift.com/container-platform/4.7/cli_reference/openshift_cli/getting-started-cli.html) - Create applications and manage OpenShift Container Platform projects from a terminal.
- [helm](https://helm.sh/docs/intro/install/) - Helm helps you manage Kubernetes applications — Helm Charts help you define, install, and upgrade even the most complex Kubernetes application.


This demo assumes your kubernetes distribution is OpenShift 4.x, and you have cluster administrator rights.  If you do not have an OpenShift cluster with these rights, we recommend a cluster from one of the Red Hat cloud partners.  

- [OpenShift on Microsoft Azure](https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it)
  - At the time of writing these instructions, there is a 30-day free developer trial.
- [OpenShift on Amazon Web Services](https://aws.amazon.com/quickstart/architecture/openshift/)
  - At the time of writing these instructions, there is a demo trial available if you complete some questionaire information.

You can use [OpenShift Local](https://developers.redhat.com/products/openshift-local/overview) as well.  The only limitation with local development is the inability for anyone else to access your cluster.

## Setup Instructions

1. Ensure you have an OpenShift 4.x cluster running and accessible to you.

- **IMPORTANT** - This cluster must be using and generating certificates from a trusted CA.  If it does not, you will not get full functionality of the demo. It will break in spots where tools will not accept untrusted certs.

2. Log into your cluster `oc` cli.  You'll need a terminal and web browser to complete this task.

  - Access the OpenShift web console.
  - At the top right of the web console, you'll see your username, click it.  This will drop down a submenu with several options.
  - Select the `Copy login command` option.
  - A new tab will open. You may be prompted to re-enter your credentials. If so, enter the same credentials that use to access the OpenShift web console.
  - You will be taken to a new webpage with the blue text of `Display Token` at the top left-hand side of the page. Click that text.
  - Find the header `Login with this token`
  - Under the header `Login with this token`, you will see a login command that beings with `oc login --token= ...`.  It will resemble a command such as this one:

  *Example OC Login Command. DO NOT COPY AND PASTE THIS.*

  ```shell
  oc login --token=sha256~12dHbGNWjMhnuJ7-qhx9tAMnjrJaRpfdswo2HoXUy8_0 --server=https://api.ci-ln-1ldd90k-72292.aws.dev.cloud.com:6443
  ```

  - Copy the full `oc login --token= ...` command from your web browser, and paste it into your termainal. Invoke the command in your terminal and follow the directions.  DO NOT COPY AND PASTE THE EXAMPLE OC LOGIN COMMAND FROM THIS README. IT WILL NOT WORK.
  - Validate you're logged in by invoking the commaned `oc status`.  The terminal will output information. The first line will say `In project default on server ...`.  
  - You are succesfully logged in if the response has the exact server used in the oc login command.

3. Clone this repository.  We will change and add files as part of the demo.  Either clone via SSH or HTTPS.

- Clone with SSH remote:

  ```shell
  git clone git@github.com:ploigos-automated-governance/1-demo.git
  ```

- Clone with HTTPS remote:

  ```shell
  git clone https://github.com/ploigos-automated-governance/1-demo.git
  ```

Once cloned, navigate into the cloned project directory.  We will begin our installation from the cloned project directory.

## Installing the Demo

### First, Install the automated governance tools & system

#### What To Expect From This First Step

This step gets you up and running with all tooling and systems you need. You'll have done the following when you finish this step.

- Installation and basic configuration of the following tools in the `devsecops` namespace:
  - Gitea - Source Code Repository
  - OpenShift Pipelines (Tekton) - Continuous Integration
  - OpenShift GitOps (ArgoCD) - Continuous Deployment
  - Nexus - Artifact Repository & Container Registry
  - SonarQube - Static Code Analysis
  - Selenium - User Acceptance Testing
- Installation and basic configuration of the following tools in the `sigstore` namespace:
  - Rekor - Transparency Log

There are some baked in assumptions with this install.  They are as follows:

- The kubernetes distribution is OpenShift 4.x
- You are not already using the namespaces
  -  `devsecops`
  -  `sigstore`

#### Let's Get Started!

Let's install and configure the software factory!  We are using [Kustomize](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/#1-make-a-kustomization-file) to simplify this process.

**IMPORTANT**
Our root directory, unless otherwise stated in the directions, will be the `1-demo` directory.  Many of these directions assume you are in the `1-demo` directory.  If not stated otherwise, make sure to run commands from the `1-demo` directory.

**1. Run the software factory installation script.**

This command starts the installation.

```shell
./install.sh
``` 

**Now, We Wait**

This begins the 5 - 10 minute installation process.  If the network connection is slower than normal, this could take upwards of 15 minutes. It is normal for it to retry creating resources multiple times, because multiple interdependent resources are being created asynchronously.

To validate the platform has been set up properly, do the following.

  - Within the `devsecops` project, access the logs of the pod named: ```
ploigos-operator-controller-manager-[random-characters-here]```. If complete, the logs will be done generating, and you'll see a meassage like this:
  
  ![Picture of logs for completed Ploigos Platforom install](assets/ploigos-softwrare-factory-platform-complete-screen.png)

**Viewing Your Credentials**

The script prints out information about the installed environment, including credentials. You will need this information to finish these instructions. You may want to copy it to somewhere safe.

If you lose the credentials, you can safely re-run the install script. It will not change anything important, but it will print out the same information again.

You can also access the same URLs by clicking on them in the OpenShift web console. Select Networking -> Routes in the main navigation menu. Make sure the `devsecops` project is selected. Select the URLs in the Location column.

**2. Validate tool access.**

Let's validate your tool access now. Use the information displayed by the script to log into Gitea and ArgoCD.

Now that everything is installed and you can access the tools, continue to the next steps!

**NOTE:** ArgoCD may take a few minutes to start its authentication component (dex). If you get an authentication error when you try to log in, wait for a few minutes and try again. If you still get an authentication error, restart Dex by running `oc delete po -l app.kubernetes.io/name=argocd-dex-server` and try again after another minute.

**3. Validate that Rekor install is complete.**

Installing Rekor could take an additional 3 - 5 minutes after the installation script exits.

You can open the ArgoCD web interface to validate that Rekor is up-and-running. Make sure to use the ArgoCD instance that was created in the `devsecops` namespace. Use the URL printed by the install script, or navigate to your `Routes` in the devsecops namespace and click on the `argocd-server` Location.

You'll see a box titled "rekor-application".  When the Status line says "Healthy" and "Synced", you have completely installed Rekor.

In the OpenShift web console, select Networking -> Routes in the main navigation menu. Select the `sigstore` project in the "Project:" dropdown at the top left. Then find the Location colum. Select the URL in that column. You should see a simple website with the heading `Rekor Server`.  That's it, next steps!

**4. Install the everything pipeline using Helm**

**IMPORTANT**

Make sure you are in the `1-demo` directory to do this.  Once validated, enter the following commands:

```shell
oc project devsecops
git clone https://github.com/ploigos/ploigos-charts.git
helm install -f values.yaml everything-pipeline ploigos-charts/charts/ploigos-workflow/tekton-pipeline-everything/
```

**5. Create the k8s resources for a Pipeline as a Service (EventLister / TriggerTemplate / Route).**

As with the previous step, make sure you are in the `1-demo` directory before executing these commands.

```shell
oc expose svc el-everything-pipeline
```

We are now ready for the second step.

### Second, Fork & Configure the Demo Application

Now we will fork the demo application. These commands cause Gitea to clone the upstream repositories from GitHub.com and create copies.

```shell
./fork-repo-to-gitea.sh reference-quarkus-mvn https://github.com/ploigos-automated-governance/reference-quarkus-mvn.git
./fork-repo-to-gitea.sh reference-quarkus-mvn-ops https://github.com/ploigos-automated-governance/reference-quarkus-mvn-ops.git
```

### Third, Update the Ploigos Software Factory Platform Configuration

**1. Generate new configuration objects.**

When we installed the software factory, a set of default configuration objects were created for us.  We need to create new configuration objects with modified settings. Our pipeline will use these instead of the default objects. The script below downloads the existing ConfigMap and Secret that hold the default configuration, modifies them, and creates a new ConfigMap and Secret with the updated configuration.

```shell
./generate-config.sh
```

**2. Test the pipeline with the new configuration.**

This command manually starts the pipeline for the forked demo application. After onboarding, the pipeline will start automatically when the source code changes.

```shell
oc create -f everything-pipelinerun.yml 
```

View the pipeline in the OpenShift web console.
- In the OpenShift web UI you should see a running pipeline
- In the left navigation menu, Pipelines -> Pipelines
- The pipeline should finish successfully. This may take 15+ minutes.

### Fourth, Onboard the Demo Application

1. Create webhook in gitea for demo app.

This script adds a Gitea webhook to the demo app repo that triggers the pipeline whenever the application source code changes.

```shell
./onboard-app.sh reference-quarkus-mvn
```

2. Test the webhook by editing the source code of the demo app in the Gitea UI.

- In the Gitea UI browse to the reference-quarkus-mvn project
- Select "README.md"
- Select "Edit File" (pencil icon to the top right)
- Add some text to the file
- Select "Create a new branch ..." (scroll down)
- Name the branch `feature/demo`
- Select "Propose file change"
- In the OpenShift web UI you should see another running pipeline
  - In the left navigation menu, Pipelines -> Pipelines
- The pipeline should finish successfully. This may take 15+ minutes.

##  GitLab setup instructions

These optional instructions configure GitLab for running CI/CD pipelines.

- Look up gitlab root credentials
  - The username is "root"
  - For the password, look in secret gitlab-gitlab-initial-root-password in namespace gitlab-system
- Look up gitlab URL
  - oc get route -n gitlab-system
  - It's the one that starts with "gitlab."
- Browse to that url and login using the gitlab root credentials
- New Project -> Create blank project
- Project name: reference-quarkus-mvn
- UNCHECK the checkbox for 'Initialize repository with a README'
- Select the button at the bottom to create the repo
- In Gitea, browse to the reference-quarkus-mvn project.
  - Example url: `https://[your-gitea-cluster-url]/platform/reference-quarkus-mvn`
  - Copy the Clone URL (clipboard button, top right, between the text box that contains an https: url and the 'Download Repository' button)
- In the terminal

  ```shell
  git clone <<paste the url you just copied from gitea>>
  cd reference-quarkus-mvn/
  git config http.sslVerify "false"
  ```

  - In GitLab, on the page for the new project
  - Select the 'Clone' dropdown, Select the clipboard icon under 'Clone with HTTPS'
- In the terminal

  ```shell
  git remote set-url origin <paste the url you just copied from gitlab>
  git push
  ```

  - Enter the gitlab root credentials
- Do all of that again for the project called reference-quarkus-mvn-ops
- Add the EventListner and ClusterBindingTrigger for GitLab

  ```shell
  oc create -f gitlab-ctb.yml
  oc create -f gitlab-eventlistener.yml
  ```

## Troubleshooting

### How to retrieve the admin credentials for ArgoCD

- Username

  ```shell
  oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.username | base64 -d && echo 
  ```
  
- Password

  ```shell
  oc get secret ploigos-service-account-credentials -n devsecops -o yaml | yq .data.password | base64 -d && echo 
  ```
