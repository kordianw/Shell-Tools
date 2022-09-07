#!/bin/bash

# what is the account profile?
# - master account's API keys need to be defiend in: ~/.aws/credentials
MASTER_ACCOUNT_PROFILE=development-account

# what is the target AWS profile? as defined in the ~/.aws/config
TARGET_AWS_PROFILE=sub-development-account

# what are the access keys for the sub-account we weant to create and add to ~/.aws/credentials via this script?
SUB_ACCOUNT_PROFILE=sub-$MASTER_ACCOUNT_PROFILE-mfa

#############################################

PROG=$(basename $PROG)

function update_aws_otp() {
  local token source_profile mfa_serial creds expiredate

  if [ $# -ne 1 ]; then
    echo -n "$PROG: Provide your 6-digit AWS MFA OTP token and press [ENTER]: "
    read read_otp_token
  else
    read_otp_token=$1
  fi

  if [ -z "$read_otp_token" ]; then
    echo "--FATAL: no 6-digit AWS MFA OTP token supplied or read!" >&2
    return 1
  fi

  # reset any AWS Profile var
  unset AWS_PROFILE

  echo "* MFA-SERIAL config: $ aws configure get mfa_serial --profile $MASTER_ACCOUNT_PROFILE" >&2
  mfa_serial=$(aws configure get mfa_serial --profile $MASTER_ACCOUNT_PROFILE)
  if [ -n "$mfa_serial" ]; then
    echo "... using MFA account: $mfa_serial" >&2
  else
    echo "--FATAL: could not fetch mfa_serial config based on master account $MASTER_ACCOUNT_PROFILE!" >&2
    return
  fi

  echo "* logging in with MFA and getting STS session creds: $ aws sts get-session-token --profile $MASTER_ACCOUNT_PROFILE --serial-number $mfa_serial --token-code $read_otp_token" >&2
  creds=$(aws sts get-session-token --profile $MASTER_ACCOUNT_PROFILE --serial-number $mfa_serial --token-code $read_otp_token)
  if [ -z "$creds" ]; then
    echo "--FATAL: could not login & fetch account STS credentials from master account $MASTER_ACCOUNT_PROFILE!"
    return
  fi

  echo "* configuring assume-role sub-profile: $SUB_ACCOUNT_PROFILE into ~/.aws/credentials" >&2
  aws configure set profile.$SUB_ACCOUNT_PROFILE.aws_access_key_id $(jq '.Credentials.AccessKeyId' --raw-output <<<$creds) || exit 1
  aws configure set profile.$SUB_ACCOUNT_PROFILE.aws_secret_access_key $(jq '.Credentials.SecretAccessKey' --raw-output <<<$creds) || exit 1
  aws configure set profile.$SUB_ACCOUNT_PROFILE.aws_session_token $(jq '.Credentials.SessionToken' --raw-output <<<$creds) || exit 1

  # verify that we now have this new profile added to credentials
  if grep -q "^.$SUB_MASTER_ACCOUNT_PROFILE" ~/.aws/credentials; then
    echo "... success: $SUB_MASTER_ACCOUNT_PROFILE 24-hours credentials added to ~/.aws/credentials" >&2
  else
    echo "--FATAL: API credentials for sub-account assume-role $SUB_MASTER_ACCOUNT_PROFILE is NOT in AWS credentials file!" >&2
    exit 1
  fi

  echo "* confirm the profile $TARGET_AWS_PROFILE set: $ aws configure list" >&2
  export AWS_PROFILE=$TARGET_AWS_PROFILE
  aws configure list || exit 1

  expiredate=$(jq '.Credentials.Expiration' --raw-output <<<$creds)
  export aws_token_expirey=$(date -d "$expiredate" +%Y-%m-%dT%H:%M:%S)
  echo && echo "* NB: token will expire in 24 hours on: $aws_token_expirey local-time ($expiredate UTC)" >&2
  echo "... to use: export AWS_PROFILE=$TARGET_AWS_PROFILE"
}

function setup() {
  # do we have the AWS and JQ?
  command -v aws &>/dev/null || {
    echo "$PROG: You need \`AWS CLI' installed, eg: 'brew install awscli'" >&2
    return 1
  }
  command -v jq &>/dev/null || {
    echo "$PROG: You need \`jq' installed, eg 'brew install jq'" >&2
    return 1
  }

  # make sure we have ~/.aws/credentials and ~/.aws/config
  if [ ! -r ~/.aws/credentials -o ! -s ~/.aws/credentials ]; then
    echo "--FATAL: can't read ~/.aws/credentials API credentials file!" >&2
    exit 1
  fi
  if [ ! -r ~/.aws/config -o ! -s ~/.aws/config ]; then
    echo "--FATAL: can't read ~/.aws/config file!" >&2
    exit 1
  fi

  # check for correct entries in the AWS config files
  if ! grep -q "profile $MASTER_ACCOUNT_PROFILE" ~/.aws/config; then
    echo "--FATAL: master/parent profile $MASTER_ACCOUNT_PROFILE not in AWS config file!" >&2
    exit 1
  fi
  if ! grep -q "profile $TARGET_AWS_PROFILE" ~/.aws/config; then
    echo "--FATAL: sub target (assume role) profile $TARGET_AWS_PROFILE not in AWS config file!" >&2
    exit 1
  fi
  if ! grep -q "^mfa_serial.*mfa" ~/.aws/config; then
    echo "--FATAL: no mfa_serial entry in $MASTER_ACCOUNT_PROFILE profile in AWS config file!" >&2
    exit 1
  fi
  if ! grep -q "^role_arn.*role" ~/.aws/config; then
    echo "--FATAL: no role_arn entry in $TARGET_AWS_PROFILE profile in AWS config file!" >&2
    exit 1
  fi

  # check for correct entries for the sub-account
  if ! grep -q "^.$MASTER_ACCOUNT_PROFILE" ~/.aws/credentials; then
    echo "--FATAL: master/parent profile $MASTER_ACCOUNT_PROFILE with credentials is NOT in AWS credentials file!" >&2
    exit 1
  fi
  if ! grep -q "source_profile.*$SUB_ACCOUNT_PROFILE" ~/.aws/config; then
    echo "--FATAL: sub target (assume role) MFA profile $SUB_ACCOUNT_PROFILE not in AWS config file!" >&2
    exit 1
  fi
}

#
# MAIN
#
setup
update_aws_otp

# EOF