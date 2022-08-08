#!/bin/bash
#
# Script to setup:
# - GCP (Google Cloud Platform) DevShell (free, Debian, ethemeral-shared-CPU VM w/5GB HOME)
# - AWS (Amazon Web Services) Cloud9 Shell (paid per-hour via dedicated EC2, 30 mins timeout for auto-shutdown)
#
# * NOTES:
# GCP: download the Google Cloud SDK (Linux works on Cygwin): https://cloud.google.com/sdk/docs/install-sdk#linux
# GCP: no need to initialize or do anything, just run as-is
# GCP: LOGIN: ~/google-cloud-sdk/bin/gcloud auth login --no-launch-browser
# GCP: Get the hostname to SSH in on port 6000 - already in ~/.ssh/config (may need IP ranges)
# GCP: there is an alias in ~/.zshrc for this already:
# GCP: # ~/google-cloud-sdk/bin/gcloud cloud-shell ssh --dry-run
# GCP: URL for web-use: https://console.cloud.google.com/cloudshell/editor?shellonly=true
# GCP: Documentation: https://cloud.google.com/shell/docs/how-cloud-shell-works
#
# GCP: NB: runs ~/.customize_environment script as root upon machine provisioning (/var/log/customize*, /google/devshell/customize_environment_done)
# GCP: NB: limits: 20mins after logout resets VM (you get a new VM), 50 hrs/week usage limit (7hrs/day), 12hr max session, 5GB home-dir deleted >120 days (4 months) of inactivity
# GCP: to use `gcloud' correctly, set your GCP project ID, eg: DEVSHELL_PROJECT_ID=kw-general-purpose
# GCP: for privacy, set: ~/google-cloud-sdk/bin/gcloud config set disable_usage_reporting true
# GCP: **web-url**: https://console.cloud.google.com/cloudshell/editor?shellonly=true
#
# * By Kordian Witek <code [at] kordy.com>, Jun 2020
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

function setup_gcp()
{
  update_scripts;
  check_root;

  #
  # credentials from Google Domains
  #
  CRED_FILE=google-domains-dyndns-secrets.yaml
  CONFIG_YAML_FILE=$CRED_FILE   # default
  [ -s ~/bin/scripts/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=~/bin/scripts/Config-Files/$CRED_FILE
  [ -s ~/src/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=~/src/Config-Files/$CRED_FILE
  [ -s ~/playground/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=~/playground/Config-Files/$CRED_FILE
  [ -s ./src/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=./src/Config-Files/$CRED_FILE
  [ -s ./playground/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=./playground/Config-Files/$CRED_FILE
  [ -s ../../Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=../../Config-Files/$CRED_FILE
  [ -s ../Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=../Config-Files/$CRED_FILE
  [ -s ./Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=./Config-Files/$CRED_FILE
  [ -s ./$CRED_FILE ] && CONFIG_YAML_FILE=./$CRED_FILE

  # PARSE YAML FILE
  # - assigns config items into variables, prefixed with "conf_"
  eval $(parse_yaml $CONFIG_YAML_FILE "conf_")

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

# gcp-shell.kordy.com: update dynamic DNS entry
echo && echo \"* [\`date +%H:%M\`] update \`gcp-shell.kordy.com' DYNAMIC DNS\"
IP=\`dig +short myip.opendns.com @resolver1.opendns.com\`
curl \"https://$conf_gcp_shell_user:$conf_gcp_shell_password@domains.google.com/nic/update?hostname=$conf_gcp_shell_dns&myip=\$IP\" &

# set env as non-interactive, to suppress errors in screen installation
export DEBIAN_FRONTEND=\"noninteractive\"
# echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# install ZSH & set as default for \`kordian'
echo && echo \"* [\`date +%H:%M\`] install+setup: zsh\"
apt install -qq -y zsh
chsh --shell /bin/zsh kordian

# install additional packages
echo && echo \"* [\`date +%H:%M\`] install screen+sshpass\"
apt install -qq -y screen sshpass

# change system's timezone
echo && echo \"* [\`date +%H:%M\`] changing system's timezone to local timezone\"
~kordian/bin/scripts/setup-linux-system.sh -TZ

# switch off accessibility options
echo && echo \"* [\`date +%H:%M\`] set gcloud accessibility/screen_reader=false, for better table handling\"
gcloud config set accessibility/screen_reader false

echo \"---> end-run (Phase 1) as \`whoami\`: \`date\`\"

# PHASE 2 - SW INSTALL -> ~5mins
echo && echo \"* [\`date +%H:%M\`] starting Phase 2 (~5 mins) - SOFTWARE INSTALL\"
nice ~kordian/bin/scripts/setup-linux-system.sh -GENPKG

echo \"---> end-run (Phase 2) as \`whoami\`: \`date\`\"

# EOF" > ~/.customize_environment
  chmod 755 ~/.customize_environment >&/dev/null

  # ZSH/SCREEN/SSHPASS
  # - we need sshpass for easier syncing later on (we use if safely)
  if [ ! -x /bin/zsh -o ! -x /bin/screen -o ! -x /bin/sshpass ]; then
    echo "** installing key packages..."
    [ ! -x /bin/zsh ] && sudo apt install -qq -y zsh
    [ ! -x /bin/screen ] && sudo apt install -qq -y screen
    [ ! -x /bin/sshpass ] && sudo apt install -qq -y sshpass
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
    echo && echo "** stopping un-needed service: docker,snapd (to reclaim memory)..."
    if ps aux | grep -q "[d]ockerd"; then
      sudo service docker stop
    fi
    if ps aux | grep -q "[s]napd"; then
      sudo service snapd stop
    fi
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

   # check that config file exists
   if [ ! -r $1 ]; then
     echo "--FATAL: config YAML file \"$1\" doesn't exist!" 1>&2
     exit 99
   fi

   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |

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
  #
  CRED_FILE=google-domains-dyndns-secrets.yaml
  CONFIG_YAML_FILE=$CRED_FILE   # default
  [ -s ~/bin/scripts/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=~/bin/scripts/Config-Files/$CRED_FILE
  [ -s ~/src/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=~/src/Config-Files/$CRED_FILE
  [ -s ~/playground/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=~/playground/Config-Files/$CRED_FILE
  [ -s ./src/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=./src/Config-Files/$CRED_FILE
  [ -s ./playground/Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=./playground/Config-Files/$CRED_FILE
  [ -s ../../Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=../../Config-Files/$CRED_FILE
  [ -s ../Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=../Config-Files/$CRED_FILE
  [ -s ./Config-Files/$CRED_FILE ] && CONFIG_YAML_FILE=./Config-Files/$CRED_FILE
  [ -s ./$CRED_FILE ] && CONFIG_YAML_FILE=./$CRED_FILE

  # PARSE YAML FILE
  # - assigns config items into variables, prefixed with "conf_"
  eval $(parse_yaml $CONFIG_YAML_FILE "conf_")

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
  echo "* [$HOST] current external IP is: $IP"

  # get DNS
  DNS_NAME=`host $IP| awk '{print $NF}' | sed 's/\.$//'`
  if [ -n "$DNS_NAME" ]; then
    echo "* [$HOST] external DNS name is: << $DNS_NAME >>"
  else
    echo "* [$HOST] no external DNS entry!"
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
      echo "* [$HOST] updating DYN_DNS for $conf_nexus_dns -> $IP"
      curl "https://$conf_nexus_user:$conf_nexus_password@domains.google.com/nic/update?hostname=$conf_nexus_dns&myip=$IP"
    else
      echo "* [$HOST] DONE! DNS for \`$conf_nexus_dns' is already set to $IP"
    fi
  # ->>> GCP-SHELL
  elif echo $HOST | egrep -q "^cs-.*default$"; then
    # is the IP already what it should be?
    DNS=`host $conf_gcp_shell_dns | awk '{print $NF}'`
    if [ "$DNS" != "$IP" ]; then
      echo "* [$HOST] updating DYN_DNS for $conf_gcp_shell_dns -> $IP"
      curl "https://$conf_gcp_shell_user:$conf_gcp_shell_password@domains.google.com/nic/update?hostname=$conf_gcp_shell_dns&myip=$IP"
    else
      echo "* [$HOST] DONE! DNS for \`$conf_gcp_shell_dns' is already set to $IP"
    fi
  # ->>> NO-USE-CASE YET!
  else
    echo "--FATAL: no configured DYN-DNS use-case for \'$HOST'" 1>&2
    exit 99
  fi
}

#
# MAIN
#

####################
PROG=`basename $0`
if [ "$1" = "-h" -o "$1" = "--help" ]; then
  cat <<! >&2
$PROG: Script to setup AWS Cloud9 and GCP CloudShell
       * install the most important PKGs, for convenience, dev, etc

Usage: $PROG <options> [param]
        -c9       sets-up AWS Cloud9
                  * runs: ./bkup-and-transfer.sh -dlupd
                  * runs: ./bkup-and-transfer.sh -setup
                  * stops memory hungry services: containerd,docker,mysql,apache2,snapd

        -gcp      sets-up GCP Cloud Shell
                  * runs: ./bkup-and-transfer.sh -dlupd
                  * runs: ./bkup-and-transfer.sh -setup
                  * creates/updates ~/.customize_environment
                  * [if needed ] installs ZSH, SCREEN, SSHPASS
                  * [if needed ] sets ZSH as default shell
                  * [if needed ] stops memory hungry process if <4GB RAM: docker,snapd
                  * updates Dynamic DNS

        -sw       installs additional software
                  * uses \`setup_linux-server.sh -GENPKG'

        -dyn_dns  update Google Dynamic DNS
                  * nexus
                  * gcp-cloudshell

        -cloud_bkup <IP|DNS>  backs-up Cloud Server Home DIR

        -h      this screen
!
elif [ "$1" = "-c9" ]; then
  setup_c9;
elif [ "$1" = "-gcp" ]; then
  setup_gcp;
elif [ "$1" = "-sw" ]; then
  install_sw;
elif [ "$1" = "-cloud_bkup" ]; then
  backup_cloud_home $2;
elif [ "$1" = "-dyn_dns" ]; then
  update_dyn_dns;
elif echo `hostname` | grep -q "devshell-vm"; then
  echo "- assuming GCP DevShell VM..." 1>&2
  setup_gcp;
  update_dyn_dns;
elif [ -n "$DEVSHELL_SERVER_URL" -o -n "$DEVSHELL_SERVER_BASE_URL" ]; then
  echo "- assuming GCP Cloud Shell VM..." 1>&2
  setup_gcp;
  update_dyn_dns;
elif [ -e $HOME/.c9 ]; then
  echo "- assuming AWS Cloud9 VM..." 1>&2
  setup_c9;
else
  echo "$PROG: see usage via \`$PROG --help' ..." 2>&1
  exit 1
fi

# EOF
