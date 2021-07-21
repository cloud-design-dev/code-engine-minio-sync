<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
  - [Preparing Accounts](#preparing-accounts)
    - [Source Account](#source-account)
      - [Create Service ID](#create-service-id)
      - [Create Reader access policy for newly created service id](#create-reader-access-policy-for-newly-created-service-id)
      - [Generate HMAC credentials tied to our service ID](#generate-hmac-credentials-tied-to-our-service-id)
    - [Destination Account](#destination-account)
      - [Create Service ID](#create-service-id-1)
      - [Create Reader access policy for newly created service id](#create-reader-access-policy-for-newly-created-service-id-1)
      - [Generate HMAC credentials tied to our service ID](#generate-hmac-credentials-tied-to-our-service-id-1)
  - [Create Code Engine Project via Cloud Shell](#create-code-engine-project-via-cloud-shell)
  - [Deploy Sync Environment](#deploy-sync-environment)
  - [Inputs](#inputs)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Overview
In this guide I will show you how to sync ICOS bucket objects between accounts using [Code Engine](https://cloud.ibm.com/docs/codeengine). Code Engine provides a platform to unify the deployment of all of your container-based applications on a Kubernetes-based infrastructure. The Code Engine experience is designed so that you can focus on writing code without the need for you to learn, or even know about, Kubernetes.

> Code Engine is currently an experimental offering and all resources are deleted every 7 days.

## Preparing Accounts
We will be using Cloud Shell to generate Service IDs and Object Storage credentials for both the source and destination accounts. 

### Source Account 
We will create a service ID on the source account. A service ID identifies a service or application similar to how a user ID identifies a user. We can assign specific access policies to the service ID that restrict permissions for using specific services: in this case it gets read-only access to an IBM Cloud Object Storage bucket. 

#### Create Service ID
```shell
$ ibmcloud iam service-id-create <name-of-your-service-id> --description "Service ID for read-only access to bucket" --output json
```

![Service ID Creation](https://dsc.cloud/quickshare/source-service-id.png)

#### Create Reader access policy for newly created service id
Now we will limit the scope of this service ID to have read only access to our source Object Storage bucket. 

```shell
$ ibmcloud iam service-policy-create <Service ID> --roles Reader --service-name cloud-object-storage --service-instance <Service Instance GUID> --resource-type bucket --resource <bucket-name>
```

*Service Instance GUID*  - This is the GUID of the Cloud Object Storage instance. You can retrieve this with the command: `ibmcloud resource service-instance <name of icos instance>`

![Expected Output Example](https://dsc.cloud/quickshare/create-source-service-policy.png)

#### Generate HMAC credentials tied to our service ID 
In order for the Minio client to talk to each Object Storage instance it will need HMAC credentials (Access Key and Secret Key in S3 parlance). 

```shell
$ ibmcloud resource service-key-create source-icos-service-creds Reader --instance-id <Service Instance GUID> --service-id <Service ID> --parameters '{"HMAC":true}'
```
Save the **access_key_id** and **secret_access_key** as we will be using these in our Code Engine project. 

![Create HMAC Credentials](https://dsc.cloud/quickshare/source-hmac-credentials.png)

---------------------------------------------------------------

### Destination Account
We will create a service ID on the destination account. A service ID identifies a service or application similar to how a user ID identifies a user. We can assign specific access policies to the service ID that restrict permissions for using specific services: in this case it gets write access to an IBM Cloud Object Storage bucket.  

#### Create Service ID
```shell
$ ibmcloud iam service-id-create <name-of-your-service-id> --description "Service ID for write access to bucket" --output json
```

![Expected Output Example](https://dsc.cloud/quickshare/destination-service-id.png)

#### Create Reader access policy for newly created service id
Now we will limit the scope of this service ID to have read only access to our source Object Storage bucket. 

```shell 
$ ibmcloud iam service-policy-create <Service ID> --roles Writer --service-name cloud-object-storage --service-instance <Service Instance GUID> --resource-type bucket --resource <bucket-name>
```

*Service Instance GUID*  - This is the GUID of the Cloud Object Storage instance. You can retrieve this with the command: `ibmcloud resource service-instance <name of icos instance>`

#### Generate HMAC credentials tied to our service ID 
We'll follow the same procedure as last time to generate the HMAC credentials, but this time on the destination account.

```shell
$ ibmcloud resource service-key-create destination-icos-service-creds Writer --instance-id <Service Instance GUID> --service-id <Service ID> --parameters '{"HMAC":true}'
```
Save the **access_key_id** and **secret_access_key** as we will be using these in with our Code Engine project. 

## Create Code Engine Project via Cloud Shell
In order to create our Code Engine project we need to make sure that our cloud shell session is targeting the correct resource group. You can do this by using the `target -g` option with the IBM Cloud CLI. 

```shell
$ ibmcloud target -g <Resource Group>
```
With the correct Resource Group set, we can now create our Code Engine project. We add the `--target` flag to ensure that future Code Engine commands are targeting the correct project.

```
$ ibmcloud ce project create -n <project_name> --target
```
![Create Code Engine Project](https://dsc.cloud/quickshare/ce-create-project.png)

## Deploy Sync Environment

1. Clone this repository

```shell
git clone https://github.com/cloud-design-dev/code-engine-minio-sync.git
cd code-engine-minio-sync
```

1. Copy `variables.example` to `.env`:

```shell
   cp variables.example .env 
```

1. Edit `.env` to match your environment. See [inputs](#inputs) for available options.
1. Create Code Engine Secret:

```shell
ibmcloud ce secret create --name ce-sync-secret --from-literal SOURCE_ACCESS_KEY="${SOURCE_ACCESS_KEY}" \
--from-literal SOURCE_SECRET_KEY="${SOURCE_SECRET_KEY}" --from-literal SOURCE_REGION="${SOURCE_REGION}" \
--from-literal SOURCE_BUCKET="${SOURCE_BUCKET}" --from-literal DESTINATION_REGION="${DESTINATION_REGION}" \
--from-literal DESTINATION_ACCESS_KEY="${DESTINATION_ACCESS_KEY}" --from-literal DESTINATION_SECRET_KEY="${DESTINATION_SECRET_KEY}" \
--from-literal DESTINATION_BUCKET="${DESTINATION_BUCKET}"
```

1. Create Code Engine Job:

```sh
ibmcloud ce job create --name mcsyncjob --image greyhoundforty/mcsync:latest --env-from-secret ce-sync-secret
```

## Inputs

| Name | Description |
|------|-------------|
| SOURCE\_ACCESS\_KEY | Access Key generated on Source account |
| SOURCE\_SECRET\_KEY | Secret Key generated on Source account |
| SOURCE\_REGION | Cloud Object Storage endpoint for the Source bucket |
| SOURCE\_BUCKET | Name of bucket on Source account |
| DESTINATION\_ACCESS\_KEY | Access Key generated on Destination account |
| DESTINATION\_SECRET\_KEY | Secret Key generated on Destination account | 
| DESTINATION\_REGION | Cloud Object Storage endpoint for the Destination bucket |
| DESTINATION\_BUCKET | Name of bucket on Destination account |
