#!/usr/bin/env bash
set -eo pipefail

# functions to create S3 bucket for terraform state
function create_s3_state_bucket() {
  local bucket_name=${1}
  local region=${2}
  local prefix=${3}
  local tags=${4}

  if [[ -z ${bucket_name} ]]; then
    echo "Bucket name is required"
    exit 1
  fi

  if [[ -z ${region} ]]; then
    echo "Region is required"
    exit 1
  fi

  if [[ -z ${prefix} ]]; then
    echo "Prefix is required"
    exit 1
  fi

  if [[ -z ${tags} ]]; then
    echo "Tags are required"
    exit 1
  fi

  local tags_json=$(echo ${tags} | jq -r 'to_entries | map("\(.key)=\(.value)") | join("&")')

  if aws s3api head-bucket --bucket "${bucket_name}" 2>/dev/null; then
      echo "Bucket ${bucket_name} already exists. Continuing..."
  else
    echo "Creating bucket ${bucket_name}..."
    aws s3api create-bucket \
      --bucket ${bucket_name} \
      --region ${region} \
      --create-bucket-configuration LocationConstraint=${region}
  fi
  }

