#!/bin/bash
#
# Script to setup:
# - GCP (Google Cloud Platform) DevShell (free, KVM, Debian, ephemeral-shared-CPU VM w/5GB HOME, sudo, web+SSH available)
# - AWS (Amazon Web Services) CloudShell (free, XenVM, Amazon Linux 2, ephemeral-shared-CPU VM w/1GB HOME, web-only, sudo, no SSH available)
# - AWS (Amazon Web Services) Cloud9 Shell (paid per-hour via dedicated EC2, 30 mins timeout for auto-shutdown)
# - Azure Cloud Shell (free, Hyper-V, CBL Linux, ephemeral-shared-CPU VM w/5GB HOME (paid), web-only, no sudo, no SSH available)
#
# *** Google Cloud Shell:
# =======================
# - based on Debian Linux, with 5GB persistent $HOME, 4 x vCPU, 16GB of RAM, SSD+HDD
# - to use SSH via external IP, download Google Cloud SDK (Linux version works on Cygwin): https://cloud.google.com/sdk/docs/install-sdk#linux
# - sudo available - can install additional packages via apt install
# - no need to initialize or do anything, just run `gcloud' as-is:
# LOGIN/AUTH-LINK: ~/google-cloud-sdk/bin/gcloud auth login --no-launch-browser
#
# Get the hostname to SSH in on port 6000 - already in ~/.ssh/config (may need IP ranges)
# # ~/google-cloud-sdk/bin/gcloud cloud-shell ssh --dry-run
#
# NB: runs ~/.customize_environment script as root upon machine provisioning (/var/log/customize*, /google/devshell/customize_environment_done)
# NB: limits: 20mins after logout resets VM (you get a new VM), 50 hrs/week usage limit (7hrs/day), 12hr max session, 5GB home-dir deleted >120 days (4 months) of inactivity
# - to use `gcloud' correctly, set your GCP project ID, eg: DEVSHELL_PROJECT_ID=kw-general-purpose
# - for privacy, set: ~/google-cloud-sdk/bin/gcloud config set disable_usage_reporting true
# **web-url**: https://console.cloud.google.com/cloudshell/editor?shellonly=true
#
# Documentation: https://cloud.google.com/shell/docs/how-cloud-shell-works
#
#
# *** AWS CloudShell:
# ===================
# - based on Amazon Linux 2 (based on RHEL), with 1GB persistent $HOME (per-region), 2 x vCPU, 4GB RAM, SSD (all)
# NB: limits: 20-30mins after logout resets VM (you get a new VM), max 12 hour session time, weekly usage limit (not sure?), 12hr max session, 1GB home-dir deleted >120 days (4 months) of inactivity
# - sudo available - can install additional packages via yum
# - web-only, no external IP address
# ** web-url**: https://console.aws.amazon.com/cloudshell/home?region=us-east-1
#
# Documentation: https://docs.aws.amazon.com/cloudshell/
#
#
# *** Azure Cloud Shell:
# ======================
# - based CBL Linux (based on Debian), with 5GB persistent 5GB $HOME, 2 x vCPU, 4GB RAM, HDD (no SSD)
# - based on CBL - Common Base Linux (Microsoft Linux distribution), which is Debian like
# - NB: no root access, no sudo, just your $HOME and /tmp, can not install additional system-wide packages/tools
#       -> see suggestions: https://edyoung.github.io/blog/install_tools_locally/
# - NB: 20 mins timeout, 5GB home (paid), long-running sessions are terminated 
# **web-url**: https://shell.azure.com
#
# Documentation: https://docs.microsoft.com/en-us/azure/cloud-shell/overview
#
#
# Pros+Cons:
# ==========
# GCP Cloud Shell:
# + SSH+web access
# + sudo
# + standard version of Linux (Ubuntu)
# + 4 vCPU + 16GB (incl. modern CPU)
# + ~/.customize_env, most-flexible/customizable
# - no SSD
# - strict session limits
#
# AWS CloudShell:
# + sudo
# + SSD
# - older HW
# - non-standard Linux (Amazon Linux 2)
# - small Homedir @ 1GB
# - seems slowest to start-up
#
# Azure Cloud Shell:
# + recent HW
# + fastest to start-up
# - no sudo
# - non-standard Linux (CBL Linux)
# - web-only, no SSH
# - charged for the 5GB Homedir
# - no SSD
#
#
# * By Kordian W. <code [at] kordy.com>, Jun 2020
#

#
# FUNCTIONS
#

function check_root()
{
  if [ "$EUID" -ne 0 ]; then
    sudo -n whoami >&/dev/null
    if [ $? -ne 0 ]; then
      echo "--FATAL: this script can only run with sudo/root privileges, \`$USER' doesn't have them!" 1>&2
      exit 99
    fi
  fi
}

function update_scripts()
{
  if [ ! -d ~/src ]; then
    echo "--FATAL: the account \`$USER' on \``hostname`' is not a standard setup for this: no ~/src dir!" 1>&2
    exit 98
  elif [ ! -x ~/src/bkup-and-transfer.sh ]; then
    echo "--FATAL: the account \`$USER' on \``hostname`' is not a standard setup for this: no ~/src/bkup-and-transfer.sh script!" 1>&2
    exit 99
  fi

  echo "** updating scripts..."
  cd ~/src && ./bkup-and-transfer.sh -dlupd || exit 1
  cd ~/src && ./bkup-and-transfer.sh -setup || exit 1
  cd - >&/dev/null
}

function setup_c9()
{
  update_scripts;
  check_root;

  # stop services taking up CPU & MEM
  # - can always be switched back on when necessary
  sudo service containerd stop
  sudo service docker stop
  sudo service mysql stop
  sudo service apache2 stop
  sudo service snapd stop
}

function connect_gcp_cloudshell()
{
  #######################################

  # location of Google Cloud SDK?
  # - if not in system path
  GOOGLE_CLOUD_SDK=~/google-cloud-sdk

  #######################################

  # What is the DNS alias for GCP Shell?
  GCP_DNS_ALIAS="$1"
  if [ -z "$GCP_DNS_ALIAS" ]; then
    echo "--FATAL: please supply the GCP DNS Alias/DynDNS hostname!" 1>&2
    exit 1
  fi

  # is it alive?
  echo -ne "* [`date +%H:%M`] check if \`$GCP_DNS_ALIAS' (:6000) is alive... " 1>&2
  if timeout 1 bash -c "cat < /dev/null > /dev/tcp/$GCP_DNS_ALIAS/6000"; then
    echo "yes, connecting!" 1>&2
    START_TIME=`date "+%s"`

    #
    # SSH
    #
    ssh $GCP_DNS_ALIAS
    RC=$?

    # if the IP was somehow reused and we can't get in...
    if [ $RC -eq 255 ]; then
      # update DYN_DNS - we have to invalidate
      echo -ne "* [`date +%H:%M`] alive, but can't connect - invalidating \"$GCP_DNS_ALIAS\" Dynamic DNS IP ... " 1>&2
      eval $(parse_yaml "google-domains-dyndns-secrets.yaml" "conf_")
      curl -fsSL "https://$conf_gcp_shell_user:$conf_gcp_shell_password@domains.google.com/nic/update?hostname=$conf_gcp_shell_dns&myip=1.1.1.1" && echo
      exit 1
    elif [ $RC -ne 0 ]; then
      echo "--> error: \`ssh $GCP_DNS_ALIAS' returned non-zero exit code RC=$RC"
    fi
  else
    echo && echo "* [`date +%H:%M`] it's not alive, requesting new GCP Cloud Shell via \`gcloud'..." 1>&2

    # check that we have the SDK
    if [ ! -d "$GOOGLE_CLOUD_SDK" ]; then
      echo "--FATAL: no Google Cloud SDK in $GOOGLE_CLOUD_SDK !" 1>&2
      exit 99
    fi

    TMP=/tmp/gcp-out-$$

    # do we have `gcloud' ?
    if ! which gcloud >&/dev/null; then
      GCLOUD=$GOOGLE_CLOUD_SDK/bin/gcloud
      if [ ! -x $GCLOUD ]; then
        echo "--FATAL: no \`gcloud' executable in $GCLOUD!" 1>&2
        exit 99
      fi
    else
      GCLOUD=gcloud
    fi

    #
    # REQUEST GCP CLOUD SHELL
    #
    $GCLOUD cloud-shell ssh --dry-run | egrep -v 'Automatic authentication with GCP CLI tools in Cloud Shell is disabled. To enable, please rerun command with' | tee -a $TMP

    if [ $? -ne 0 ]; then
      echo "--FATAL: error requesting GCP Cloud Shell - \`gcloud' returned RC=$?!" 1>&2
      exit 99
    fi

    IP=`awk '/ssh.*@/{print $9}' $TMP | sed 's/^[a-z]*@//'`
    if [ -z "$IP" ]; then
      echo "--FATAL: weren't able to get the IP address from the gcloud command!" 1>&2
      exit 99
    fi

    # clean-up
    rm -f $TMP

    # update DYN_DNS - while we wait for machine to fully come up!
    echo -ne "* [`date +%H:%M`] updating \"$GCP_DNS_ALIAS\" Dynamic DNS to $IP ... " 1>&2
    eval $(parse_yaml "google-domains-dyndns-secrets.yaml" "conf_")
    curl -fsSL "https://$conf_gcp_shell_user:$conf_gcp_shell_password@domains.google.com/nic/update?hostname=$conf_gcp_shell_dns&myip=$IP"

    # connect via IP while we wait for the DNS to change
    IP_MASK=`echo $IP | sed 's/^\([0-9][0-9][0-9]*\.[0-9][0-9]*\)\..*/\1/'`
    if egrep -q "^Host.*shell.* $IP_MASK\.*" ~/.ssh/config; then
      echo -e "\n* [`date +%H:%M`] IP $IP is in ~/.ssh/config via $IP_MASK.*, waiting 5 secs to connect..." 1>&2
      sleep 5   # 5-6 secs seems reasonable as the time it takes to install zsh - tweaked based on experience
      GCP_DNS_ALIAS=$IP
    else
      # wait for the DNS to update...
      echo -ne "\n* [`date +%H:%M`] waiting for \`$GCP_DNS_ALIAS' to be updated with the IP \`$IP' " 1>&2

      while ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/$GCP_DNS_ALIAS/6000"
      do
        echo -ne "."
        sleep 2
      done
      echo
    fi

    #
    # SSH
    #
    START_TIME=`date "+%s"`
    echo "* [`date +%H:%M`] success: \`ssh $GCP_DNS_ALIAS'..." 1>&2
    ssh $GCP_DNS_ALIAS
    RC=$?

    if [ $RC -ne 0 ]; then
      echo "   --> error: \`ssh $GCP_DNS_ALIAS' returned non-zero exit code RC=$RC"
    fi
  fi

  # work out end time
  END_TIME=`date +%s`
  TIME_TAKEN=$(( $END_TIME - $START_TIME ))
  if [ $TIME_TAKEN -gt 60 ]; then
    TIME_TAKEN=`echo "($END_TIME - $START_TIME) / 60" | bc -l | sed 's/\(...\).*/\1/; s/\.$//; s/\.[012]$//'`
    TIME_TAKEN="$TIME_TAKEN mins"
  else
    TIME_TAKEN="$TIME_TAKEN secs"
  fi

  # final info message
  echo "... cloudshell session finished at `date +%H:%M` after $TIME_TAKEN." | sed 's/ 1 mins/ 1 min/' 1>&2

  exit $RC
}

function setup_gcp_shell_VM()
{
  update_scripts;
  check_root;

  #
  # credentials from Google Domains
  # - parses YAML & assigns config items into variables, prefixed with "conf_"
  #
  eval $(parse_yaml "google-domains-dyndns-secrets.yaml" "conf_")

  # check that we have the right stuff
  if [ -z "$conf_google_main_user" ]; then
    echo "--FATAL: no main Google user config!" 1>&2
    exit 98
  fi
  if [ -z "$conf_gcp_shell_dns" ]; then
    echo "--FATAL: no GCP Shell DNS config!" 1>&2
    exit 99
  fi

  # set-up ~/.customize_environment
echo "#!/bin/sh
##
## Kordian's config to customize GCP CloudShell
##
# - note: this runs as \`root' once during initial cloudshell creation/boot-up
# - runs in background, when done touches: /google/devshell/customize_environment_done
# - logs in /var/log/customize_environment

# set the EDT timezone
export TZ=\"America/New_York\"

echo \"---> start-run as \`whoami\`: \`date\`\"

# P1: install ZSH & set as default for \`$conf_google_main_user'
echo && echo \"* [\`date +%H:%M\`] install+setup: zsh\"
nice -n -5 apt-get install -qq -y zsh
nice -n -5 chsh --shell /bin/zsh $conf_google_main_user

# P2: $conf_gcp_shell_dns: update dynamic DNS entry
echo && echo \"* [\`date +%H:%M\`] update << $conf_gcp_shell_dns >> DYNAMIC DNS\"
IP=\`dig +short myip.opendns.com @resolver1.opendns.com\`
nice -n -5 curl -fsSL \"https://$conf_gcp_shell_user:$conf_gcp_shell_password@domains.google.com/nic/update?hostname=$conf_gcp_shell_dns&myip=\$IP\"

# set env as non-interactive, to suppress errors in screen installation
export DEBIAN_FRONTEND=\"noninteractive\"
# echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# P3: install additional key packages
echo && echo \"* [\`date +%H:%M\`] install screen+sshpass\"
apt-get install -qq -y screen sshpass

# P4: change system's timezone to local
echo && echo \"* [\`date +%H:%M\`] changing system's timezone to local timezone\"
~$conf_google_main_user/bin/scripts/setup-linux-system.sh -TZ

# switch off accessibility options
echo && echo \"* [\`date +%H:%M\`] set gcloud accessibility/screen_reader=false, for better table handling\"
nice gcloud config set accessibility/screen_reader false

echo \"---> end-run (Phase 1) as \`whoami\`: \`date\`\"

# PHASE 2 - SW INSTALL (all other packages) -> ~5mins
echo && echo \"* [\`date +%H:%M\`] starting Phase 2 (~5 mins) - SOFTWARE INSTALL\"
nice ~$conf_google_main_user/bin/scripts/setup-linux-system.sh -GENPKG

echo \"---> end-run (Phase 2) as \`whoami\`: \`date\`\"

# EOF" > ~/.customize_environment
  chmod 755 ~/.customize_environment >&/dev/null

  # ZSH/SCREEN/SSHPASS
  # - we need sshpass for easier syncing later on (we use if safely)
  if [ ! -x /bin/zsh -o ! -x /bin/screen -o ! -x /bin/sshpass ]; then
    echo "** installing key packages..."
    [ ! -x /bin/zsh ] && sudo apt-get install -qq -y zsh
    [ ! -x /bin/screen ] && sudo apt-get install -qq -y screen
    [ ! -x /bin/sshpass ] && sudo apt-get install -qq -y sshpass
  fi

  # chsh ZSH
  if ! getent passwd $USER | grep -q "zsh"; then
    echo && echo "** setting up ZSH ..."
    ~/bin/scripts/setup-linux-system.sh -ZSH || exit 99
  fi

  # stop some services which take up CPU/memory
  # - only if less than 4GB of RAM remaining
  FREE_MEM=`free -m | awk '/Mem/{print $NF}'`
  if [ $FREE_MEM -lt 4000 ]; then
    echo && echo "** stopping un-needed service: docker,containerd (to reclaim memory)..."
    if ps aux | grep -q "[d]ockerd"; then
      sudo service docker stop
    fi
    if ps aux | grep -q "[s]ontainterd"; then
      sudo service containerd stop
    fi

    # NB: leave snapd running as `gcloud' binary is a snap package
    #if ps aux | grep -q "[s]napd"; then
    #  sudo service snapd stop
    #fi
  fi

  # start ZSH
  if [ "$SHELL" != "/bin/zsh" ]; then
    echo && echo "** restarting with ZSH..."
    exec zsh
  fi
}

function install_sw()
{
  check_root;
  ~/bin/scripts/setup-linux-system.sh -GENPKG
}

function backup_cloud_home()
{
  # defaults
  SERVICE="cloud-server"

  # read from USER if not provided as a param
  HOST_ADDRESS="$1"
  if [ ! -n "$HOST_ADDRESS" ]; then
    echo -n "Please enter DNS/IP address of the Cloud Host (ssh): "
    read HOST_ADDRESS
  fi

  if [ -n $HOST_ADDRESS ]; then
    # use-cases
    if echo "$HOST_ADDRESS" | egrep -q 'gcp-shell|^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'; then
      SERVICE="gcp-cloudshell"
    else
      SERVICE=`echo $HOST_ADDRESS | awk -F. '{print $1}'`
    fi

    # construct target dir backup
    TARGET_DIR=$HOME
    [ -d $HOME/Backups ] && TARGET_DIR=$HOME/Backups
    TARGET_BACKUP="$TARGET_DIR/$SERVICE-bkup-`date +%Y-%m-%d`.tar.gz"

    # status message
    echo "--> backing up to: $TARGET_BACKUP"

    # EXEC:
    ssh $HOST_ADDRESS "cd /home && tar \
      --exclude='src/dl' \
      --exclude='google-cloud-sdk' \
      --exclude='example-scripts.tar.gz.gpg' \
      --exclude='Mail/tmp' \
      --exclude='_gsdata_' \
      --exclude='.bash_history' \
      --exclude='.lesshst' \
      --exclude='.wget-hsts' \
      --exclude='.zcompdump' \
      --exclude='.zsh_history' \
      --exclude='.viminfo' \
      --exclude='.gnupg' \
      --exclude='.cache' \
      --exclude='.ebcache' \
      --exclude='.Trash' \
      --exclude='.sudo_as_admin_successful' \
      --exclude='.theia/logs' \
      --exclude='.config/gcloud/logs' \
      --exclude='.git/objects' \
      --exclude='.git/hooks' \
      --exclude='.git/refs' \
      --exclude='.git/logs' \
      --exclude='public_html/kordianw.github.io/.git/objects' \
      --exclude='public_html/kordianw.github.io/.git/hooks' \
      --exclude='public_html/kordianw.github.io/.git/refs' \
      --exclude='public_html/kordianw.github.io/.git/logs' \
      --exclude='src/kordianw.github.io/.git/objects' \
      --exclude='src/kordianw.github.io/.git/hooks' \
      --exclude='src/kordianw.github.io/.git/refs' \
      --exclude='src/kordianw.github.io/.git/logs' \
      -cvf - \$USER | gzip -9" >$TARGET_BACKUP

    if [ -s "$TARGET_BACKUP" ]; then
      chmod 600 $TARGET_BACKUP >&/dev/null
      echo && ls -lh $TARGET_BACKUP
    else
      [ -e "$TARGET_BACKUP" -a ! -s "$TARGET_BACKUP" ] && rm -f "$TARGET_BACKUP"
      echo "*** tar backup unsuccessful, see errors above!" 1>&2
    fi
  else
    echo "--FATAL: No Google Cloud Shell IP Address - Nothing read!" 1>&2
    exit 99
  fi
}

function parse_yaml()
{
  local prefix=$2
  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')

  # find the location of `Config-Files' where we store all our configs
  YAML_FILE=$1   # no-path-yet
  [ -r ~/bin/scripts/Config-Files/$1 ] && YAML_FILE=~/bin/scripts/Config-Files/$1
  [ -r ~/src/Config-Files/$1 ] && YAML_FILE=~/src/Config-Files/$1
  [ -r ~/playground/Config-Files/$1 ] && YAML_FILE=~/playground/Config-Files/$1
  [ -r ./bin/scripts/Config-Files/$1 ] && YAML_FILE=./bin/scripts/Config-Files/$1
  [ -r ./src/Config-Files/$1 ] && YAML_FILE=./src/Config-Files/$1
  [ -r ./playground/Config-Files/$1 ] && YAML_FILE=./playground/Config-Files/$1
  [ -r ../../Config-Files/$1 ] && YAML_FILE=../../Config-Files/$1
  [ -r ../Config-Files/$1 ] && YAML_FILE=../Config-Files/$1
  [ -r ./Config-Files/$1 ] && YAML_FILE=./Config-Files/$1
  [ -r `dirname $0`/$1 ] && YAML_FILE=`dirname $0`/$1
  [ -r ./$1 ] && YAML_FILE=./$1

  # check that config file exists
  if [ ! -r $YAML_FILE ]; then
    echo "--FATAL: config YAML file \"$YAML_FILE\" doesn't exist!" 1>&2
    exit 98
  fi
  if [ ! -s $YAML_FILE ]; then
    echo "--FATAL: config YAML file \"$YAML_FILE\" is EMPTY!" 1>&2
    exit 99
  fi

  sed -ne "s|^\($s\):|\1|" \
       -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
       -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $YAML_FILE |

  awk -F$fs '{
     indent = length($1)/2;
     vname[indent] = $2;
     for (i in vname) {if (i > indent) {delete vname[i]}}
     if (length($3) > 0) {
        vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
        printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
     }
  }'
}

function update_dyn_dns()
{
  #
  # credentials from Google Domains
  # - parses YAML & assigns config items into variables, prefixed with "conf_"
  #
  eval $(parse_yaml "google-domains-dyndns-secrets.yaml" "conf_")
  if [ -z "$conf_google_main_user" ]; then
    echo "--FATAL: were not able to parse YAML file properly... exiting!" 1>&2
    exit 99
  fi

  # check HOST variable is set
  HOST=`hostname`
  if [ -z "$HOST" ]; then
    echo "--FATAL: the `hostname` has no HOST variable set!" 1>&2
    exit 98
  fi

  # check that we have dig
  if ! which dig >&/dev/null; then
    echo "--FATAL: the \`dig' binary is not available on `hostname`!" 1>&2
    exit 98
  fi

  # first, get the IP
  IP=`dig +short myip.opendns.com @resolver1.opendns.com`
  if [ -z "$IP" ]; then
    echo "--FATAL: can't work out the external IP addresss for $HOST!" 1>&2
    exit 99
  fi
  echo "* [$HOST] info: current external IP is: $IP"

  # get DNS
  DNS_NAME=`host $IP| awk '!/not found/{print $NF}' | sed 's/\.$//'`
  if [ -n "$DNS_NAME" ]; then
    echo "* [$HOST] info: external DNS name is: << $DNS_NAME >>"
  else
    echo "* [$HOST] info: no external DNS entry!"
  fi

  #
  # EXEC
  # - do the work
  #
  # ->>> NEXUS
  if echo $HOST | grep -q nexus; then
    # is the IP already what it should be?
    DNS=`host $conf_nexus_dns | awk '{print $NF}'`
    if [ "$DNS" != "$IP" ]; then
      echo "* [$HOST] action: updating DYN_DNS for $conf_nexus_dns -> $IP"
      curl -fsSL "https://$conf_nexus_user:$conf_nexus_password@domains.google.com/nic/update?hostname=$conf_nexus_dns&myip=$IP"
      if [ $? -ne 0 ]; then
        echo "--FATAL: curl returned error updating $conf_nexus_dns to $IP!" 1>&2
        exit 99
      fi
    else
      echo "* [$HOST] ALREADY WAS DONE! DNS for \`$conf_nexus_dns' was already set to $IP"
    fi
  # ->>> GCP-SHELL
  elif echo $HOST | egrep -q "^cs-.*default$"; then
    # is the IP already what it should be?
    DNS=`host $conf_gcp_shell_dns | awk '{print $NF}'`
    if [ "$DNS" != "$IP" ]; then
      echo "* [$HOST] action: updating DYN_DNS for $conf_gcp_shell_dns -> $IP"
      curl -fsSL "https://$conf_gcp_shell_user:$conf_gcp_shell_password@domains.google.com/nic/update?hostname=$conf_gcp_shell_dns&myip=$IP"
      if [ $? -ne 0 ]; then
        echo "--FATAL: curl returned error updating $conf_gcp_shell_dns to $IP!" 1>&2
        exit 99
      fi
    else
      echo "* [$HOST] ALREADY WAS DONE! DNS for \`$conf_gcp_shell_dns' was already set to $IP"
    fi
  # ->>> NO-USE-CASE YET!
  else
    echo "--FATAL: no configured DYN-DNS use-case for \'$HOST'" 1>&2
    exit 99
  fi
}

function assume_gcp_shell_setup()
{
  # double check that this really is a GCP host
  if [ -d ~/src -a -d /google/devshell ]; then
    echo "- assuming GCP DevShell VM - running setup & dyndns update..." 1>&2
    setup_gcp_shell_VM;
    update_dyn_dns;
  else
    echo "--FATAL: doesn't seem like a Google Cloud Shell server - no ~/src, no /google/devshell..." 1>&2
    echo && echo "$PROG: see usage via \`$PROG --help' ..." 1>&2
    exit 1
  fi
}

#
# MAIN
#

####################
PROG=`basename $0`
if [ "$1" = "-h" -o "$1" = "--help" -o "$1" = "-help" ]; then
  cat <<! >&2
$PROG: Script to setup Cloud VMs, eg: GCP Cloud Shell, AWS CloudShell, Azure Cloud Shell
       * install the most important PKGs, for convenience, dev, etc

Usage: $PROG <options> [param]
        -cloudshell <dyn_dns_hostname>
                    connects/requests GCP Cloud Shell (via SSH)
                    * checks if it exists via DynDNS
                    * creates a new GCP Cloud Shell session /OR/
                    * connects via SSH to an existing GCP Cloud Shell session
                    * updates DynamicDNS with the latest IP of the Cloud Shell
                    NB: only GCP currently provides SSH access to Cloud Shell

        -gcp_setup  sets-up GCP Cloud Shell VM
                    * runs: ./bkup-and-transfer.sh -dlupd
                    * runs: ./bkup-and-transfer.sh -setup
                    * creates/updates ~/.customize_environment
                    * [if needed ] installs ZSH, SCREEN, SSHPASS
                    * [if needed ] sets ZSH as default shell
                    * [if needed ] stops memory hungry process if <4GB RAM: docker,snapd
                    * [if needed ] updates Dynamic DNS
                    NOTE: Most of this should already be handled by ~/.customize_environment

        -c9_setup   sets-up AWS Cloud9 [paid] VM
                    * runs: ./bkup-and-transfer.sh -dlupd
                    * runs: ./bkup-and-transfer.sh -setup
                    * stops memory hungry services: containerd,docker,mysql,apache2,snapd

        -dyn_dns    update Google Dynamic DNS
                    * nexus (main SSH server)
                    * GCP Cloud Shell

        -sw         installs additional software: * uses \`setup_linux-server.sh -GENPKG'

        -cloud_bkup <IP|DNS>  backs-up Cloud Server Home DIR

!
elif [ "$1" = "-c9_setup" ]; then
  setup_c9;
elif [ "$1" = "-gcp_setup" ]; then
  setup_gcp_shell_VM;
elif [ "$1" = "-cloudshell" ]; then
  connect_gcp_cloudshell $2;
elif [ "$1" = "-sw" ]; then
  install_sw;
elif [ "$1" = "-cloud_bkup" ]; then
  backup_cloud_home $2;
elif [ "$1" = "-dyn_dns" -o "$1" = "-dyn_DNS" -o "$1" = "-dyndns" ]; then
  update_dyn_dns;
elif echo `hostname` | grep -q "devshell-vm"; then
  assume_gcp_shell_setup;
elif [ -n "$DEVSHELL_SERVER_URL" -o -n "$DEVSHELL_SERVER_BASE_URL" ]; then
  assume_gcp_shell_setup;
elif [ -e $HOME/.c9 ]; then
  echo "- assuming AWS Cloud9 VM..." 1>&2
  setup_c9;
else
  echo -e "$PROG: see usage via \`$PROG --help':\n" 1>&2
  exec $0 --help
fi

# EOF
