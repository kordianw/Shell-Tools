#!/bin/bash
#
# AWS Helper Script - a variety of tools to help with AWS CLI/API Usage
#
# One key function is to login to a master AWS account with MFA and then assume-role to a sub-account
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

#### CONFIG:

# what are the default REGIONS we focus on, in checking running instances?
# - can be filtered via a param
KEY_REGIONS="us-east-1 us-east-2 ca-central-1"

# what is the target profile AWS prefix? use the prefix to define sub-profile in: ~/.aws/config
# - this prefix needs to be used to define a 2nd entry in the AWS config file with this prefix
# - the full role name with prefix is what we will use for assume-role, API key credentials will be generated
TARGET_AWS_PREFIX=sub

# what are the access keys for the sub-account we want to create and add to ~/.aws/credentials via this script?
# - this is the source_profile = line in ~/.aws/config
SOURCE_ACCOUNT_PROFILE="sub-<PROFILE>-mfa"

#############################################
PROG=$(basename $0)

function update_aws_otp() {
  local token source_profile mfa_serial creds expiredate

  # reset any AWS Profile var
  # - can also use: --profile=<profile>
  if [ -n "$AWS_PROFILE" ]; then
    echo "* unsetting env: AWS_PROFILE to have clean environment"
    unset AWS_PROFILE
  fi

  echo "* MFA-SERIAL config: $ aws configure get mfa_serial --profile $MASTER_ACCOUNT_PROFILE" >&2
  mfa_serial=$(aws configure get mfa_serial --profile $MASTER_ACCOUNT_PROFILE)
  if [ -n "$mfa_serial" ]; then
    ACCOUNT_INFO=$(sed 's/arn:aws:iam:://' <<<$mfa_serial)
    echo "... using AWS account: << $(echo_green $ACCOUNT_INFO) >>" >&2
  else
    echo "--FATAL: could not fetch mfa_serial config based on master account $MASTER_ACCOUNT_PROFILE!" >&2
    exit 1
  fi

  if [ $# -ne 1 ]; then
    echo -n "$PROG: Provide your 6-digit AWS MFA OTP token and press [ENTER]: "
    read read_otp_token
  else
    read_otp_token=$1
  fi

  if [ -z "$read_otp_token" ]; then
    echo "--FATAL: no 6-digit AWS MFA OTP token supplied or read!" >&2
    exit 1
  fi

  #
  # MFA:
  #
  # obtain session credentials via MFA with 36 hours expiry ie 1.5 days (86400 seconds)
  # - maximum is 36 hours (129600 seconds) - 1.5 days
  # - default is 12 hours (43200 seconds) - 0.5 days
  # - good option is 24 hours (86400 seconds) - 1 day
  echo -e "* getting session token with MFA to obtain session creds:\n$ aws sts get-session-token --profile $MASTER_ACCOUNT_PROFILE --serial-number $mfa_serial --token-code $read_otp_token" >&2
  creds=$(aws sts get-session-token --profile $MASTER_ACCOUNT_PROFILE --serial-number $mfa_serial --token-code $read_otp_token --duration-seconds 129600)
  if [ -z "$creds" ]; then
    echo "--FATAL: could not login & fetch account STS credentials from master account $MASTER_ACCOUNT_PROFILE!"
    exit 1
  fi

  # check AWS session
  # - can use AWS_PROFILE env-var or --profile=<profile>
  echo "* checking AWS login for profile: $MASTER_ACCOUNT_PROFILE" >&2
  export AWS_PROFILE=$MASTER_ACCOUNT_PROFILE
  echo "* $(echo_red 'AWS_PROFILE') = $(echo_cyan "$AWS_PROFILE")"
  check_aws_login

  echo "* configuring assume-role sub-profile: $SOURCE_ACCOUNT_PROFILE into ~/.aws/credentials" >&2
  aws configure set profile.$SOURCE_ACCOUNT_PROFILE.aws_access_key_id $(jq '.Credentials.AccessKeyId' --raw-output <<<$creds) || exit 1
  aws configure set profile.$SOURCE_ACCOUNT_PROFILE.aws_secret_access_key $(jq '.Credentials.SecretAccessKey' --raw-output <<<$creds) || exit 1
  aws configure set profile.$SOURCE_ACCOUNT_PROFILE.aws_session_token $(jq '.Credentials.SessionToken' --raw-output <<<$creds) || exit 1

  # verify that we now have this new profile added to credentials
  if grep -q "^.$SUB_MASTER_ACCOUNT_PROFILE" ~/.aws/credentials; then
    echo "... success: $SUB_MASTER_ACCOUNT_PROFILE 24-hours credentials added to ~/.aws/credentials" >&2
  else
    echo "--FATAL: API credentials for sub-account assume-role $SUB_MASTER_ACCOUNT_PROFILE is NOT in AWS credentials file!" >&2
    exit 1
  fi

  # confirm that we've assumed the role correctly
  # - can use AWS_PROFILE env-var or --profile=<profile>
  echo "* confirm the profile << $TARGET_AWS_PREFIX-$MASTER_ACCOUNT_PROFILE >> is correctly set:" >&2
  export AWS_PROFILE=$TARGET_AWS_PREFIX-$MASTER_ACCOUNT_PROFILE
  echo "* $(echo_red 'AWS_PROFILE') = $(echo_cyan "$AWS_PROFILE")"
  check_aws_login

  expiredate=$(jq '.Credentials.Expiration' --raw-output <<<$creds)
  export aws_token_expirey=$(date -d "$expiredate" +%Y-%m-%dT%H:%M:%S)
  echo && echo "* NB: OTP token will expire on: $aws_token_expirey local-time ($expiredate UTC)" >&2
  echo -e "... to use:\n# export AWS_PROFILE=$MASTER_ACCOUNT_PROFILE\n# export AWS_PROFILE=$TARGET_AWS_PREFIX-$MASTER_ACCOUNT_PROFILE"
}

NC='\033[0m' # No Color
function echo_cyan() {
  Cyan='\033[0;36m'
  printf "${Cyan}${@}${NC}"
}

function echo_red() {
  Red='\033[0;91m'
  printf "${Red}${@}${NC}"
}

function echo_yellow() {
  BYellow='\033[1;33m'
  printf "${BYellow}${@}${NC}"
}

function echo_green() {
  IGreen='\033[0;92m'
  printf "${IGreen}${@}${NC}"
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
    aws iam get-user | jq
  else
    echo "- AWS CLI: \`aws iam get-user' iam:GetUser query call not allowed." >&2
  fi

  # use S3 to find out owner name
  echo "* Getting Owner name via S3-API root bucket:"
  NAME=$(aws s3api list-buckets | jq '.Owner.DisplayName')
  if [ -n "$NAME" ]; then
    echo "Owner Display Name: << $(echo_green $NAME) >>"
  else
    echo "- no root-bucket S3 name from S3 API" >&2
  fi
}

function setup_basic() {
  # do we have the AWS and JQ?
  command -v aws &>/dev/null || {
    echo "$PROG: You need \`AWS CLI' installed, eg: 'brew install awscli'" >&2
    exit 99
  }
  command -v jq &>/dev/null || {
    echo "$PROG: You need \`jq' installed, eg 'brew install jq'" >&2
    exit 99
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

  # check we have credentials at all ?
  if ! grep -q "^aws_access_key_id = ...." ~/.aws/credentials; then
    echo "--FATAL: no \`aws_access_key_id' entry in AWS credentials file!" >&2
    exit 1
  fi
  if ! grep -q "^aws_secret_access_key = ...." ~/.aws/credentials; then
    echo "--FATAL: no \`aws_secret_access_key' entry in AWS credentials file!" >&2
    exit 1
  fi

  # check profile
  [ "$AWS_PROFILE" = "default" ] && AWS_PROFILE=
  if [ -n "$AWS_PROFILE" ]; then
    if ! grep -q "^\[profile $AWS_PROFILE\]" ~/.aws/config; then
      echo "* $(echo_red 'AWS_PROFILE') = $(echo_cyan "$AWS_PROFILE")"
      echo "--FATAL: profile \`$AWS_PROFILE' as defined in AWS_PROFILE env not in AWS config file ~/.aws/config!" >&2
      exit 1
    fi
    if ! grep -q "^\[$AWS_PROFILE." ~/.aws/credentials; then
      echo "--FATAL: profile \`$AWS_PROFILE' as defined in AWS_PROFILE env has no credentials in ~/.aws/credentials, run \`aws configure'" >&2
      exit 1
    fi
  fi
}

function setup_profile() {
  if [ -z "$MASTER_ACCOUNT_PROFILE" ]; then
    echo "--FATAL: master account profile not defined!" >&2
    exit 1
  fi

  # check for correct entries in the AWS config files
  if ! grep -q "^\[profile $MASTER_ACCOUNT_PROFILE\]" ~/.aws/config; then
    echo "--FATAL: master/parent profile \`$MASTER_ACCOUNT_PROFILE' not in AWS config file!" >&2
    exit 1
  fi
  if ! grep -q "^\[profile $TARGET_AWS_PREFIX-$MASTER_ACCOUNT_PROFILE\]" ~/.aws/config; then
    echo "--FATAL: sub target (assume role) profile \`$TARGET_AWS_PREFIX-$MASTER_ACCOUNT_PROFILE' not in AWS config file!" >&2
    exit 1
  fi
  if ! grep -q "^mfa_serial.*mfa" ~/.aws/config; then
    echo "--FATAL: no mfa_serial entry in \`$MASTER_ACCOUNT_PROFILE' profile in AWS config file!" >&2
    exit 1
  fi
  if ! grep -q "^role_arn.*role" ~/.aws/config; then
    echo "--FATAL: no role_arn entry in \`$TARGET_AWS_PREFIX-$MASTER_ACCOUNT_PROFILE' profile in AWS config file!" >&2
    exit 1
  fi

  # check for correct entries for the sub-account
  if ! grep -q "^\[$MASTER_ACCOUNT_PROFILE\]" ~/.aws/credentials; then
    echo "--FATAL: master/parent profile \`$MASTER_ACCOUNT_PROFILE' with credentials is NOT in AWS credentials file!" >&2
    exit 1
  fi
  if ! grep -q "source_profile.*$SOURCE_ACCOUNT_PROFILE" ~/.aws/config; then
    echo "--FATAL: sub target (assume role) MFA profile \`$SOURCE_ACCOUNT_PROFILE' not in AWS config file!" >&2
    exit 1
  fi
}

function show_env() {
  if [ -n "$AWS_PROFILE" ]; then
    echo "* current env: $(echo_red 'AWS_PROFILE') = $(echo_cyan "$AWS_PROFILE")"

    # check profile
    if [ "$AWS_PROFILE" = "default" ]; then
      if ! grep -q "^\[$AWS_PROFILE\]" ~/.aws/config; then
        echo "--FATAL: profile \`$AWS_PROFILE' as defined in AWS_PROFILE env not in AWS config file ~/.aws/config!" >&2
        exit 1
      fi
    else
      if ! grep -q "^\[profile $AWS_PROFILE\]" ~/.aws/config; then
        echo "--FATAL: profile \`$AWS_PROFILE' as defined in AWS_PROFILE env not in AWS config file ~/.aws/config!" >&2
        exit 1
      fi
    fi
    if ! grep -q "^\[$AWS_PROFILE." ~/.aws/credentials; then
      echo "--FATAL: profile \`$AWS_PROFILE' as defined in AWS_PROFILE env has no credentials in ~/.aws/credentials, run \`aws configure'" >&2
      exit 1
    fi
  else
    echo "* $(echo_red 'AWS_PROFILE') $(echo_cyan 'not currently set'), using default AWS profile"
  fi
}

function check_ec2() {
  #REGIONS=$(aws ec2 describe-regions --region us-east-1 --output text --query Regions[*].[RegionName])
  KEY_REGIONS=$(tr ' ' '\n' <<<$KEY_REGIONS)

  REGIONS=$KEY_REGIONS
  [ -n "$1" ] && REGIONS=$1
  for region in $REGIONS
  do
    echo -e "\n* EC2 Instances in '$region':";
    aws ec2 describe-instances --region $region | \
      jq '.Reservations[].Instances[] | "EC2: \(.InstanceId): \(.State.Name) << \(.Tags[]|select(.Key=="Name")|.Value) >> \(.InstanceType)/\(.Placement.AvailabilityZone), \(.KeyName), \(.PublicIpAddress) @ \(.LaunchTime)"'
    #aws ec2 describe-instances --region "$region" |\
    # jq ".Reservations[].Instances[] | {type: .InstanceType, state: .State.Name, tags: .Tags, zone: .Placement.AvailabilityZone}" --raw-output
    #aws ec2 describe-instances --output table --query "Reservations[].Instances[].{Name: Tags[?Key == 'Name'].Value | [0], Id: InstanceId, State: State.Name, Type: InstanceType, DC: Placement.AvailabilityZone, Key: KeyName, IP: PublicIpAddress, Launch: LaunchTime}"
  done
}

#
# MAIN
#
if [ $# -eq 0 -o "$1" = "-h" -o "$1" = "--help" ]; then
  cat <<! >&2
$PROG: AWS Helper Script - a variety of tools to help with AWS CLI/API Usage

Usage: $PROG <option>
       
       Options:
       -check_access    checks login/access to AWS, based on current AWS_PROFILE/default
       -check_ec2 [region] 
                        shows all running EC2 instances (in REGIONS=$KEY_REGIONS)
       -update_otp <profile> 
                        assume-role and update OTP credentials for a sub-account/sub-user
                        -> master profile: <profile>
                        -> assume-role profile: <$SUB_ACCOUNT_PREFIX-profile>

       -h    this screen
!
elif [ "$1" = "-check_access" -o "$1" = "-check-access" ]; then
  setup_basic
  show_env
  check_aws_login
elif [ "$1" = "-check_ec2" -o "$1" = "-check-ec2" ]; then
  setup_basic
  show_env
  check_ec2 $2
elif [ "$1" = "-update_otp" -o "$1" = "-update-otp" ]; then
  MASTER_ACCOUNT_PROFILE=$2
  if [ -z "$MASTER_ACCOUNT_PROFILE" ]; then
    echo "--FATAL: no master AWS profile supplied!, see \`$PROG --help'" >&2

    echo && echo "Defined profiles in ~/.aws/config:"
    grep "^\[profile ." ~/.aws/config |grep -v " sub-" | sed 's/\[/- /; s/\]$//; s/profile /defined profile: /' | sort
    exit 1
  fi
  SOURCE_ACCOUNT_PROFILE=$(sed "s/<PROFILE>/$MASTER_ACCOUNT_PROFILE/" <<<$SOURCE_ACCOUNT_PROFILE)
  setup_basic
  setup_profile
  show_env
  update_aws_otp
else
  echo "$PROG: invalid option, see \`$PROG --help'" >&2
fi

# EOF
