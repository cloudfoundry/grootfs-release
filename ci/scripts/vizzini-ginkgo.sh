#!/bin/bash -l

# set -x
set -e

ensure(){
  if [[ "${!1}" == "" ]]
  then
    echo "ERROR: ${1} param must be defined"
    exit 1
  fi
}

ensure BOSH_CERTIFICATES
ensure BOSH_TARGET
ensure BOSH_CLIENT
ensure BOSH_CLIENT_SECRET
ensure DIEGO_CREDENTIALS
ensure ENV
ensure GINKGO_NODES
ensure VERBOSE
ensure PLACEMENT_TAG

cd diego-release-git
export GOPATH=$(pwd)
cd src/code.cloudfoundry.org/vizzini

echo "$DIEGO_CREDENTIALS" | python -c 'import yaml; import sys; print yaml.load(sys.stdin).get("diego_bbs_client").get("private_key")' > client.key
echo "$DIEGO_CREDENTIALS" | python -c 'import yaml; import sys; print yaml.load(sys.stdin).get("diego_bbs_client").get("certificate")' > client.crt
echo "$BOSH_CERTIFICATES" > certificates.yml

bosh int --path "/certs/ca_cert" certificates.yml > ca_cert.crt
bosh -e $BOSH_TARGET --ca-cert ca_cert.crt alias-env bosh-director
bosh -e bosh-director --client $BOSH_CLIENT --client-secret $BOSH_CLIENT_SECRET login
DIEGO_BRAIN_ADDRESS=$(bosh -e bosh-director -d cf vms | awk '/diego-brain/ {print $4}')
DIEGO_API_ADDRESS=$(bosh -e bosh-director -d cf vms | awk '/diego-api/ {print $4}')
SSH_PROXY_PASSWORD=$(echo "$DIEGO_CREDENTIALS" | python -c 'import yaml; import sys; print yaml.load(sys.stdin).get("ssh_proxy_diego_credentials")')

EXITSTATUS=0

ginkgo \
  -nodes=${GINKGO_NODES} \
  -v=${VERBOSE} \
  -progress \
  -trace \
  -keepGoing \
  -skip="{LOCAL}" \
  -- \
  --bbs-address="https://${DIEGO_API_ADDRESS}:8889" \
  --bbs-client-cert=./client.crt \
  --bbs-client-key=./client.key \
  --rep-placement-tag=$PLACEMENT_TAG \
  --ssh-address="${DIEGO_BRAIN_ADDRESS}:2222" \
  --ssh-password=${SSH_PROXY_PASSWORD} \
  --routable-domain-suffix="grootfs-${ENV}.cf-app.com"

echo "Vizzini Complete; exit status: $EXITSTATUS"
