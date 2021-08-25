#!/bin/bash 

echo ">> starting configuration for minio"

mc --config-dir=/opt/.mc config host add source_acct https://s3."$SOURCE_REGION".cloud-object-storage.appdomain.cloud ${SOURCE_ACCESS_KEY} ${SOURCE_SECRET_KEY} --api "s3v4"

mc --config-dir=/opt/.mc config host add destination_acct https://s3."${DESTINATION_REGION}".cloud-object-storage.appdomain.cloud ${DESTINATION_ACCESS_KEY} ${DESTINATION_SECRET_KEY} --api "s3v4"

mc --config-dir=/opt/.mc alias ls

echo ">> Listing objects in source_acct bucket..." 
mc --config-dir=/opt/.mc ls source_acct/${SOURCE_BUCKET}

echo ">> Listing objects in destination_acct bucket prior to sync..."
mc --config-dir=/opt/.mc ls destination_acct/${DESTINATION_BUCKET}

echo ">> Sync buckets..."
mc --config-dir=/opt/.mc cp --recursive source_acct/${SOURCE_BUCKET}/ destination_acct/${DESTINATION_BUCKET}

echo ">> Listing objects in destination_acct bucket after sync..."
mc --config-dir=/opt/.mc ls destination_acct/${DESTINATION_BUCKET}
