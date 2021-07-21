# cross-account-sync-icos

## Prep Environment

1. Copy `variables.example` to `.env`:

   ```sh
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
