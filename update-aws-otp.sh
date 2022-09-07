#!/bin/bash
#
# Script to login to a master AWS account with MFA and then assume-role to a sub-account
# - automatically generates API Keys for the sub-account and stores into ~/.aws/credentials
# - reminds to set AWS_PROFILE for the assume-role sub-account in order to use AWS CLI
# - performs various checks to ensure the configuration is set-up correctly
#
# ~/.aws/config:
# [profile development-account]
# aws_account_id = <MASTER_AWS_ID>
# mfa_serial = arn:aws:iam::<MASTER_AWS_ID>:mfa/<USER>@<DOMAIN>.com
# region=us-east-1
# output=json
#
# [profile sub-development-account]
# role_arn = arn:aws:iam::<ROLE_AWS_ID>:role/OrganizationAccountAccessRole
# source_profile = sub-development-account-mfa
#
# [profile sub-development-account-mfa] should only exist in the credentials file as generated by this script
#
#
# ~/.aws/credentials:
# [development-account]
# aws_access_key_id = <KEY>
# aws_secret_access_key = <ACCESS_KEY>
#
#
# * By Kordian W. @ Aug 2022
#

# what is the account profile?
# - master account's profile needs to be defined in: << ~/.aws/config >>
# - master account's API keys need to be defined in: << ~/.aws/credentials >>
MASTER_ACCOUNT_PROFILE=development-account

# what is the target AWS profile? as defined in: ~/.aws/config
# - this needs to be defined as a 2nd entry in the AWS config file
# - this is what we will use for assume-role, API key credentials will be generated
TARGET_AWS_PROFILE=sub-development-account

# what are the access keys for the sub-account we weant to create and add to ~/.aws/credentials via this script?
SUB_ACCOUNT_PROFILE=sub-$MASTER_ACCOUNT_PROFILE-mfa

#############################################
PROG=$(basename $0)

function update_aws_otp() {
  local token source_profile mfa_serial creds expiredate

  # reset any AWS Profile var
  # - can also use: --profile=<profile>
  unset AWS_PROFILE

  echo "* MFA-SERIAL config: $ aws configure get mfa_serial --profile $MASTER_ACCOUNT_PROFILE" >&2
  mfa_serial=$(aws configure get mfa_serial --profile $MASTER_ACCOUNT_PROFILE)
  if [ -n "$mfa_serial" ]; then
    echo "... using AWS account: << $(sed 's/arn:aws:iam:://' <<<$mfa_serial) >>" >&2
  else
    echo "--FATAL: could not fetch mfa_serial config based on master account $MASTER_ACCOUNT_PROFILE!" >&2
    return
  fi

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

  echo -e "* logging in with MFA and getting STS session creds:\n$ aws sts get-session-token --profile $MASTER_ACCOUNT_PROFILE --serial-number $mfa_serial --token-code $read_otp_token" >&2
  creds=$(aws sts get-session-token --profile $MASTER_ACCOUNT_PROFILE --serial-number $mfa_serial --token-code $read_otp_token)
  if [ -z "$creds" ]; then
    echo "--FATAL: could not login & fetch account STS credentials from master account $MASTER_ACCOUNT_PROFILE!"
    return
  fi

  # check AWS login
  # - can use AWS_PROFILE env-var or --profile=<profile>
  echo "* checking AWS login for profile: $MASTER_ACCOUNT_PROFILE" >&2
  export AWS_PROFILE=$MASTER_ACCOUNT_PROFILE
  check_aws_login

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

  # confirm that we've assumed the role correctly
  # - can use AWS_PROFILE env-var or --profile=<profile>
  echo "* confirm the profile $TARGET_AWS_PROFILE is correctly set:" >&2
  export AWS_PROFILE=$TARGET_AWS_PROFILE
  check_aws_login

  expiredate=$(jq '.Credentials.Expiration' --raw-output <<<$creds)
  export aws_token_expirey=$(date -d "$expiredate" +%Y-%m-%dT%H:%M:%S)
  echo && echo "* NB: OTP token will expire in 24 hours on: $aws_token_expirey local-time ($expiredate UTC)" >&2
  echo -e "... to use:\n# export AWS_PROFILE=$MASTER_ACCOUNT_PROFILE\n# export AWS_PROFILE=$TARGET_AWS_PROFILE"
}

function check_aws_login() {
  # check configure list
  aws configure list || exit 1

  # check STS login
  if aws sts get-caller-identity >&/dev/null; then
    aws sts get-caller-identity | jq
  else
    aws sts get-caller-identity
    echo "--FATAL: AWS login failed!" >&2
    exit 1
  fi

  # check IAM get-user
  if aws iam get-user >&/dev/null; then
    aws iam get-user
  else
    echo "- AWS CLI: \`aws iam get-user' iam:GetUser query call not allowed!" >&2
  fi
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
    echo "--FATAL: AWS CLI not set-up: can't read ~/.aws/credentials API credentials file!" >&2
    exit 1
  fi
  if [ ! -r ~/.aws/config -o ! -s ~/.aws/config ]; then
    echo "--FATAL: AWS CLI not set-up: can't read ~/.aws/config file!" >&2
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
