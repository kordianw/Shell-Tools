#!/bin/bash

function update_aws_otp() {
  local token source_profile mfa_serial creds expiredate

  command -v aws &>/dev/null || {
    echo "$0: You need \`AWS CLI' installed, eg: 'brew install awscli'" >&2
    return
  }
  command -v jq &>/dev/null || {
    echo "$0: You need \`jq' installed, eg 'brew install jq'" >&2
    return
  }

  if [ $# -ne 1 ]; then
    echo -n "$0: Provide your OTP token and press [ENTER]: "
    read token
  else
    token=$1
  fi

  master_profile=development-account
  mfa_serial=$(aws configure get mfa_serial --profile $master_profile)
  creds=$(aws sts get-session-token --profile $master_profile --serial-number $mfa_serial --token-code $token)
  if [ -z "$creds" ]; then
    echo "$0: could not fetch credentials!"
    return
  fi

  aws configure set profile.account-mfa.aws_access_key_id $(jq '.Credentials.AccesskeyId' --raw-output <<<$creds)
  aws configure set profile.account-mfa.aws_secret_access_key $(jq '.Credentials.SecretAccesskey' --raw-output <<<$creds)
  aws configure set profile.account-mfa.aws_session_token $(jq '.Credentials.SessionToken' --raw-output <<<$creds)

  expiredate=$(jq '. Credentials.Expiration' --raw-output <<<$creds)
  export aws_token_expirey=$(date -d "$expiredate" +%Y-%m-%dT%H:%M:%SZ)
}

#
# MAIN
#
update_aws_otp

# need to export the AWS_PROFILE as defined in the -/.aws/config
#export AWS_PROFILE=automation-nonp

# EOF
