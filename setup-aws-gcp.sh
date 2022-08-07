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

function update_scripts()
{
  echo "** updating scripts..."
  cd ~/src && ./bkup-and-transfer.sh -dlupd || exit 1
  cd ~/src && ./bkup-and-transfer.sh -setup || exit 1
  cd - >&/dev/null
}

function setup_c9()
{
  update_scripts;

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

  # set-up ~/.customize_environment
echo "#!/bin/sh
##
## Kordian's config to customize GCP CloudShell
##
# - note: this runs as \`root' once during initial cloudshell creation/boot-up
# - runs in background, when done touches: /google/devshell/customize_environment_done
# - logs in /var/log/customize_environment

# set env as non-interactive, to suppress errors in screen installation
export DEBIAN_FRONTEND=\"noninteractive\"
# echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# set the EDT timezone
export TZ=\"America/New_York\"

echo \"---> start-run as \`whoami\`: \`date\`\"

# install ZSH & set as default for \`kordian'
echo \"* install+setup: zsh\"
apt install -qq -y zsh || exit 1
chsh --shell /bin/zsh kordian

# install additional packages
echo \"* install screen+sshpass\"
apt install -qq -y screen sshpass || exit 1

# switch off accessibility options
echo \"* set gcloud accessibility/screen_reader=false, for better table handling\"
gcloud config set accessibility/screen_reader false

echo \"---> end-run as \`whoami\`: \`date\`\"

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
    echo && echo "** stopping un-needed service: docker (to reclaim memory)..."
    if ps aux | grep -q "[d]ockerd"; then
      sudo service docker stop
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
    if echo "$HOST_ADDRESS" | egrep -q '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'; then
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
      --exclude='public_html/kordianw.github.io/.git/objects' \
      --exclude='public_html/kordianw.github.io/.git/logs' \
      --exclude='src/kordianw.github.io/.git/objects' \
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
        -c9     sets-up AWS Cloud9
        -gcp    sets-up GCP CloudShell

        -sw     installs additional software

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
elif echo `hostname` | grep -q "devshell-vm"; then
  echo "- assuming GCP DevShell VM..." 1>&2
  setup_gcp;
elif [ -n "$DEVSHELL_SERVER_URL" -o -n "$DEVSHELL_SERVER_BASE_URL" ]; then
  echo "- assuming GCP Cloud Shell VM..." 1>&2
  setup_gcp;
elif [ -e $HOME/.c9 ]; then
  echo "- assuming AWS Cloud9 VM..." 1>&2
  setup_c9;
else
  echo "$PROG: see usage via \`$PROG --help' ..." 2>&1
  exit 1
fi

# EOF
