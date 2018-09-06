#!/bin/bash

# Chech that Stage is not local
if [ "$STAGE" != "local" ]; then

    # Check that the environment variable has been set correctly
    if [ -z "$SECRETS_BUCKET_NAME" ]; then
        echo >&2 'error: missing SECRETS_BUCKET_NAME environment variable'
        exit 1
    fi

    # Load the S3 secrets file contents into the environment variables
    echo "LOADING SECRETS"
    exists=$(aws s3 ls s3://${SECRETS_BUCKET_NAME}/${DEPLOYMENT_CLUSTER}/${STAGE}/.secrets)
    if [ -z "$exists" ]; then
        echo "No Secrets file provided by HQ"
    else
        aws s3 cp s3://${SECRETS_BUCKET_NAME}/${DEPLOYMENT_CLUSTER}/${STAGE}/.secrets /var/config/.secrets   
        source /var/config/.secrets
    fi

    #Load env var from s3 into environment
    echo "LOADING ENV VARS"
    aws s3 cp s3://${SECRETS_BUCKET_NAME}/${DEPLOYMENT_CLUSTER}/${STAGE}/${SERVICE_NAME}/orders /var/config/${SERVICE_NAME}/orders
    source /var/config/${SERVICE_NAME}/orders
    printenv

fi
echo "STARTING SERVICE"
exec ./epistream.coffee