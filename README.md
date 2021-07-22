<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
  - [Preparing Accounts](#preparing-accounts)
    - [Source Account](#source-account)
    - [Destination Account](#destination-account)
  - [Create Code Engine Project](#create-code-engine-project)
    - [(Optional) Create Docker container via Code Engine](#optional-create-docker-container-via-code-engine)
  - [Deploy Sync Environment](#deploy-sync-environment)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Overview
In this guide I will show you how to sync [IBM Cloud Object Storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-about-cloud-object-storage) buckets between accounts using [Code Engine](https://cloud.ibm.com/docs/codeengine). Code Engine provides a platform to unify the deployment of all of your container-based applications on a Kubernetes-based infrastructure. The Code Engine experience is designed so that you can focus on writing code without the need for you to learn, or even know about, Kubernetes.

## Preparing Accounts
We will be using [Cloud Shell](https://cloud.ibm.com/docs/cloud-shell?topic=cloud-shell-shell-ui) to generate Service IDs and Object Storage credentials for both the source and destination accounts. 

We will also be creating a [Service ID](https://cloud.ibm.com/docs/account?topic=account-serviceids) on the both accounts. A service ID identifies a service or application similar to how a user ID identifies a user. We can assign specific access policies to the service ID that restrict permissions for using specific services: in this case it gets *read-only* access to an Object Storage bucket on the Source Account and *write* access an Object Storage bucket on the Destination Account.

### Source Account 

Launch a Cloud Shell session on the Source Account to begin generating our Object Storage access credentials.

**Create Service ID**

```sh
$ ibmcloud iam service-id-create SERVICE_ID_NAME --description "Service ID for read-only access to bucket"
```

*Inputs:*
> - `SERVICE_ID_NAME`: The name for the Service ID on the source account. 

**Create Reader access policy for newly created Service ID:**

Now we will limit the scope of this service ID to have read only access to our source Object Storage bucket. 

```sh
$ ibmcloud iam service-policy-create SERVICE_ID --roles Reader --service-name cloud-object-storage \
--service-instance ICOS_SERVICE_INSTANCE_ID --resource-type bucket --resource SOURCE_BUCKET_NAME
```
    
*Inputs:*
> - `SERVICE_ID`: The ID of the Service ID created in the previous step.  
> - `ICOS_SERVICE_INSTANCE_ID`: The GUID of the Cloud Object Storage instance on the source account. You can retrieve this with the command: `ibmcloud resource service-instance <name of icos instance>`
> - `SOURCE_BUCKET_NAME`: The name of the source account bucket that we will sync with the destination bucket. 

**Generate HMAC credentials tied to our service ID:**

In order for the Minio client to talk to each Object Storage instance it will need HMAC credentials (Access Key and Secret Key in S3 parlance). 

```sh
$ ibmcloud resource service-key-create SERVICE_ID_KEY_NAME Reader --instance-id ICOS_SERVICE_INSTANCE_ID \
--service-id SERVICE_ID --parameters '{"HMAC":true}'
```
    
*Inputs:*
> - `SERVICE_ID`: The ID of the Service ID created in the previous step. 
> - `ICOS_SERVICE_INSTANCE_ID`: The GUID of the Cloud Object Storage instance on the source account.
> - `SERVICE_ID_KEY_NAME`:

*Important Outputs:*
Take note of the output from the Serice Key output. These values will be used when creating our Code Engine Job.

> - `access_key_id` will be used as the variable `SOURCE_ACCESS_KEY`
> - `secret_access_key` will be used as the variable `SOURCE_SECRET_KEY`

---

### Destination Account

Launch a Cloud Shell session on the Source Account to begin generating our Object Storage access credentials.

**Create Service ID**

```sh
$ ibmcloud iam service-id-create SERVICE_ID_NAME --description "Service ID for write access to destination account bucket"
```

*Inputs:*
> - `SERVICE_ID_NAME`: The name for the Service ID on the source account. 


**Create Reader access policy for newly created service ID: **

Now we will add a Writer policy to our destination bucket bound to the Service ID. 

```sh
$ ibmcloud iam service-policy-create SERVICE_ID --roles Writer --service-name cloud-object-storage \
--service-instance ICOS_SERVICE_INSTANCE_ID --resource-type bucket --resource DESTINATION_BUCKET_NAME
```
    
*Inputs:*
> - `SERVICE_ID`: The ID of the Service ID created in the previous step.  
> - `ICOS_SERVICE_INSTANCE_ID`: The GUID of the Cloud Object Storage instance on the source account. You can retrieve this with the command: `ibmcloud resource service-instance <name of icos instance>`
> - `DESTINATION_BUCKET_NAME`: The name of the source account bucket that we will sync with the destination bucket. 

**Generate HMAC credentials tied to our service ID: **

We'll follow the same procedure as last time to generate the HMAC credentials, but this time on the destination account.

```sh
$ ibmcloud resource service-key-create SERVICE_ID_KEY_NAME Reader --instance-id ICOS_SERVICE_INSTANCE_ID \
--service-id SERVICE_ID --parameters '{"HMAC":true}'
```
    
*Inputs:*
> - `SERVICE_ID`: The ID of the Service ID created in the previous step. 
> - `ICOS_SERVICE_INSTANCE_ID`: The GUID of the Cloud Object Storage instance on the source account.
> - `SERVICE_ID_KEY_NAME`:

*Important Outputs:*
Take note of the output from the Serice Key output. These values will be used when creating our Code Engine Job.

> - `access_key_id` will be used as the variable `DESTINATION_ACCESS_KEY`
> - `secret_access_key` will be used as the variable `DESTINATION_SECRET_KEY`

---

## Create Code Engine Project

**Target Resource Group:**

On the account where you will deploy and run the Code Engine job to sync the buckets jump back in to Cloud Shell. In order to create our Code Engine project we need to make sure that our cloud shell session is targeting the correct resource group. 

```shell
$ ibmcloud target -g RESOURCE_GROUP
```
    
*Inputs:*
> - `RESOURCE_GROUP`: Name of the Resource Group to assign to Code Engine Project. 

**Create Code Engine Project:**
With the correct Resource Group set, we can now create our Code Engine project. We add the `--target` flag to ensure that future Code Engine commands are targeting the correct project.

```
$ ibmcloud ce project create -n PROJECT_NAME --target
```
    
*Inputs:*
> - `PROJECT_NAME`: Name of the Code Engine Project. 

### (Optional) Create Docker container via Code Engine

The default image used to sync the buckets is `greyhoundforty/mcsync:latest`. If you would like to build the container yourself and stick it in to IBM Cloud Container Registry fork this [repository](https://github.com/cloud-design-dev/code-engine-minio-sync), update the Dockerfile if needed, and then use Code Engine to build the image as outlined below.

**Create Code Engine Repository Secret:**

In order to push our container image in to IBM Cloud Container Registry we need to first set up a Code Engine [registry secret](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#add-registry-access-ce).

```sh
  ibmcloud ce registry create --name REGISTRY_SECRET_NAME --username iamapikey \
  --password IBMCLOUD_API_KEY --email YOUR_IBM_ACCOUNT_EMAIL --server ICR_ENDPOINT 
```

Inputs:
> - `REGISTRY_SECRET_NAME`: The name of the Code Engine Registry Secret.
> - `IBMCLOUD_API_KEY`: The IBM Cloud API Key for your account. 
> - `YOUR_IBM_ACCOUNT_EMAIL`: The email associated with your IBM Account.
> - `ICR_ENDPOINT`: The IBM Container Registry Endpoint to use. See [full list](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#registry_regions)

**Create Container Build:**

```sh
  ic ce build create --name BUILD_NAME --image us.icr.io/NAMESPACE/CONTAINER_NAME:1 --source FORKED_REPO_URL \
  --rs REGISTRY_SECRET_NAME --size small 
```

Inputs:
> - `BUILD_NAME`: The name of the build job.
> - `NAMESPACE`: The IBM Container Registry Namespace where the image will be stored. See [this guide]() if you need to create a namespace.
> - `CONTAINER_NAME`: The name of the container. 
> - `FORKED_REPO_URL`: The Github URL for the forked version of the sync container.
> - `REGISTRY_SECRET_NAME:` The name of the Container Registry Secreate created in the previous step. 

**Run container build:** 

```sh
ibmcloud ce buildrun submit --build BUILD_NAME
```

Inputs:
> - `BUILD_NAME`: The name of the build job created in the previous step.

--- 

## Deploy Sync Environment

**Clone this repository:**

```sh
git clone https://github.com/cloud-design-dev/code-engine-minio-sync.git
cd code-engine-minio-sync
```

**Copy `variables.example` to `.env`:**

```shell
  cp variables.example .env 
```

**Edit `.env` to match your environment: **

See [inputs](#inputs) for available options.

**Once updated source the file for use in our session:**

```sh
source .env
```

**Create Code Engine Secret:**

```
ibmcloud ce secret create --name CODE_ENGINE_SECRET --from-literal SOURCE_ACCESS_KEY="${SOURCE_ACCESS_KEY}" \
--from-literal SOURCE_SECRET_KEY="${SOURCE_SECRET_KEY}" --from-literal SOURCE_REGION="${SOURCE_REGION}" \
--from-literal SOURCE_BUCKET="${SOURCE_BUCKET}" --from-literal DESTINATION_REGION="${DESTINATION_REGION}" \
--from-literal DESTINATION_ACCESS_KEY="${DESTINATION_ACCESS_KEY}" --from-literal DESTINATION_SECRET_KEY="${DESTINATION_SECRET_KEY}" \
--from-literal DESTINATION_BUCKET="${DESTINATION_BUCKET}"
```

*Inputs:*
> - `CODE_ENGINE_SECRET`: Name of the Code Engine Secret. All other variables are picked up from our `.env` file. 

**Create Code Engine Job:**

If you created your own version of the container image as outlined above you will need to update the command and replace `greyhoundforty/mcsync:latest` with your image.

```sh
ibmcloud ce job create --name JOB_NAME --image greyhoundforty/mcsync:latest --env-from-secret CODE_ENGINE_SECRET
```

*Inputs:*
> - `JOB_NAME`: The name of the Code Engine job.
> - `CODE_ENGINE_SECRET`: Name of the Code Engine Secret. All other variables are picked up from our `.env` file. 

**Submit Code Engine Job:**

```sh
ibmcloud ce jobrun submit --job JOB_NAME
```

*Inputs:*
> - `JOB_NAME`: The name of the Code Engine job.

**Check the status of the job:**

Depending on the size and number of objects that you are syncing the job could take a bit of time. You can check on the status of the job run by issuing the command:

```sh
ibmcloud ce jobrun get --name JOB_NAME
```

