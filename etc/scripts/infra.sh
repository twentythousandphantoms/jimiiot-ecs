#!/usr/bin/env bash
set -eo pipefail

function set_infra_config () {
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

  # terraform data directory:
  # e.g. /tmp/jimiiot-dev-eu-west-2@infra
  TF_DATA_DIR=${TF_DATA_DIR:-"/tmp/${PRODUCT_CONFIG_REGION}-${PRODUCT_CONFIG_NAME}-${PRODUCT_CONFIG_ENV}@infra"}

  # terraform config directory:
  # e.g. ./etc/config/eu-west-2/sandbox
  CONFIG_DIR="${PRODUCT_CONFIG_PATH}/${PRODUCT_CONFIG_REGION}-${PRODUCT_CONFIG_NAME}-${PRODUCT_CONFIG_ENV}"

  # infra configuration file:
  # e.g. ./etc/config/eu-west-2-jimiioy-dev/config.hcl
  CONFIG_FILE="${CONFIG_DIR}/config.hcl"

  # common tags and global configuration
  STATE_JSON=$(cat ${CONFIG_DIR}/state-config.json)

  # infra s3 backend configuration
  CLOUD_PROVIDER=$(echo ${STATE_JSON} | jq -r ".provider")
  BACKEND_BUCKET=$(echo ${STATE_JSON} | jq -r ".state.bucket" )
  BACKEND_REGION=$(echo ${STATE_JSON} | jq -r ".state.region" )
  BACKEND_PREFIX=$(echo ${STATE_JSON} | jq -r ".state.prefix")
  BACKEND_KEY="${BACKEND_PREFIX}/${PRODUCT_CONFIG_REGION}-infra.tfstate"
}

function print_infra_config () {
  echo "#### Project configuration"
  echo "> Product: ${PRODUCT_CONFIG_NAME}"
  echo ""
  echo "> Terraform data directory: ${TF_DATA_DIR}"
  echo "> Cloud provider: ${CLOUD_PROVIDER}"
  echo "> Deployment region: ${PRODUCT_CONFIG_REGION}"
  echo "> Deployment environment: ${PRODUCT_CONFIG_ENV}"
  echo ""
  echo "> State bucket region: ${BACKEND_REGION}"
  echo "> State bucket: ${BACKEND_BUCKET}"
  echo "> State key: ${BACKEND_KEY}"
  echo ""
}

function show_infra_config() {
    set_infra_config;
    print_infra_config;
}

function init_infra_module () {
  show_infra_config;

  if [[ ! -d ${TF_DATA_DIR} ]] || [[ ! -z "${PRODUCT_MODULE_RECONFIGURE}" ]]; then
    create_s3_state_bucket ${BACKEND_BUCKET} ${BACKEND_REGION} ${BACKEND_KEY} "Name=${BACKEND_BUCKET},Environment=${PRODUCT_CONFIG_ENV}"
    mkdir -p ${TF_DATA_DIR}
    env TF_DATA_DIR=${TF_DATA_DIR} \
      terraform init -input=false \
        -backend-config=region=${BACKEND_REGION} \
        -backend-config=bucket=${BACKEND_BUCKET} \
        -backend-config=key=${BACKEND_KEY}
  else
    echo "+ No initialization required.."
  fi
}

function plan_infra_provision () {
  init_infra_module;

  echo "+ Planning..."
  env TF_DATA_DIR=${TF_DATA_DIR} \
    terraform plan \
      -input=false \
      -var=region=${PRODUCT_CONFIG_REGION} \
      -var-file=${CONFIG_FILE} \
      -out tfplan
}

# module apply
function create_infra () {
  init_infra_module;

  echo "+ Applying..."
  #enable_auto_approve;

  env TF_DATA_DIR=${TF_DATA_DIR} \
    terraform apply \
      -input=false \
      -auto-approve \
      -var=region=${PRODUCT_CONFIG_REGION} \
      -var-file=${CONFIG_FILE}
}

# module refresh
function refresh_infra () {
  init_infra_module;

  echo "+ Refreshing..."
  env TF_DATA_DIR=${TF_DATA_DIR} \
    terraform refresh \
      -input=false \
      -var=region=${PRODUCT_CONFIG_REGION} \
      -var-file=${CONFIG_FILE}
}

# module destroy
function destroy_infra () {
  refresh_infra;

  echo "+ Removing..."
  #enable_auto_approve;

  env TF_DATA_DIR=${TF_DATA_DIR} \
    terraform destroy \
      -input=false \
      -auto-approve \
      -var=region=${PRODUCT_CONFIG_REGION} \
      -var-file=${CONFIG_FILE}
}
