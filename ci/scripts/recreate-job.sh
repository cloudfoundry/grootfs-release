#!/bin/bash -e

ensure(){
  if [[ "${!1}" == "" ]]
  then
    echo "ERROR: ${1} param must be defined"
    exit 1
  fi
}

ensure BOSH_TARGET
ensure BOSH_CLIENT
ensure BOSH_CLIENT_SECRET
ensure BOSH_CERTIFICATES
ensure BOSH_DEPLOYMENT
ensure JOB_NAME


echo "$BOSH_CERTIFICATES" > certificates.yml
bosh int --path "/certs/ca_cert" certificates.yml > ca_cert.crt

echo "Running performance tests..."
bosh -e $BOSH_TARGET --ca-cert ca_cert.crt alias-env bosh-director
bosh -e bosh-director --client $BOSH_CLIENT --client-secret $BOSH_CLIENT_SECRET login
bosh -e bosh-director -d $BOSH_DEPLOYMENT -n recreate $JOB_NAME
