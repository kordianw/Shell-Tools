#!/bin/bash
#
# Script to setup:
# - GCP (Google Cloud Platform) DevShell (free, ethemeral-shared-CPU VM)
# - AWS (Amazon Web Services) Cloud9 Shell (paid per-hour via dedicated EC2, 30 mins timeout for auto-shutdown)
#
# * NOTES:
# GCP: Get the hostname to SSH in on port 6000 (boosted mode):
# GCP: # ~/google-cloud-sdk/bin/gcloud alpha cloud-shell ssh --boosted --dry-run
# GCP: URL for web-use: https://console.cloud.google.com/cloudshell/editor?shellonly=true
# GCP: Documentation: https://cloud.google.com/shell/docs/how-cloud-shell-works
#
# GCP: boost mode moves from E2-shared-core `e2-small' to `e2-medium' (Debian w/5GB disk) for 24 hours (doubles your RAM from 2GB to 4GB + more BW)
# GVP: * details: https://cloud.google.com/compute/docs/machine-types#e2_shared-core_machine_types
# GCP: NB: runs ~/.customize_environment script as root upon machine provisioning (/var/log/customize*, /google/devshell/customize_environment_done)
# GCP: limits: 20mins after logout resets VM, 50 hrs/week usage limit (7hrs/day), 12hr max session, 5GB home-dir deleted >120 days (4 months) of inactivity
# GCP: to use `gcloud' correctly, set your GCP project ID, eg: DEVSHELL_PROJECT_ID=kw-general-purpose
# GCP: for privacy, set: ~/google-cloud-sdk/bin/gcloud config set disable_usage_reporting true
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

  #
  # what are my GCP key packages to install?
  #
  KEY_PACKAGES="zsh screen sshpass"

  # set-up ~/.customize_environment
echo "#!/bin/sh
# Kordian's config to customize GCP CloudShell
# - note: this runs as \`root'

# install ZSH
apt install -qq -y zsh || exit 1
chsh --shell /bin/zsh $USER

# install additional packages
apt install -qq -y $KEY_PACKAGES || exit 1

# EOF" > ~/.customize_environment
  chmod 755 ~/.customize_environment >&/dev/null

  echo "** installing key packages..."
  sudo apt install -qq -y zsh screen sshpass

  # chsh ZSH
  if ! getent passwd $USER | grep -q "zsh"; then
    echo && echo "** setting up ZSH ..."
    ~/bin/scripts/setup-linux-system.sh -ZSH || exit 99
  fi

  # stop some services which take up CPU/memory
  echo && echo "** stopping un-needed services..."
  if ps aux | grep -q "[d]ockerd"; then
    sudo service docker stop
  fi

  # start ZSH
  if [ "$SHELL" != "/bin/zsh" ]; then
    echo && echo "** starting ZSH..."
    exec zsh
  fi
}

function install_sw()
{
  ~/bin/scripts/setup-linux-system.sh -GENPKG
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

        -h      this screen
!
elif [ "$1" = "-c9" ]; then
  setup_c9;
elif [ "$1" = "-gcp" ]; then
  setup_gcp;
elif [ "$1" = "-sw" ]; then
  install_sw;
elif echo `hostname` | grep -q "devshell-vm"; then
  echo "- assuming GCP DevShell VM..." 1>&2
  setup_gcp;
elif [ -e $HOME/.c9 ]; then
  echo "- assuming AWS Cloud9 VM..." 1>&2
  setup_c9;
else
  echo "$PROG: see usage via \`$PROG --help' ..." 2>&1
  exit 1
fi

# EOF
