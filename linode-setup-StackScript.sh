#!/bin/bash
# Linode setup StackScript for Debian/Ubuntu Linux
# - sets a default hostname
# - sets up the system's timezone
# - does an apt-update
# - installs `zsh'
# - sets up a main user and adds to sudo group
# - installs fail2ban to help guard against SSH attacks
# - sets up key packages: screen/tmux/sshpass (under `nice')
# - performs an apt-upgrade to bring the system to the latest level (under `nice')
#
# * By Kordian W. <code [at] kordy.com>, Aug 2022
#

##################################
# what local user to create?
LOCAL_USER="<USER>"

# name of the key setup script
WGET_URL="<URL>"

TZ="America/New_York"
##################################

# enable logging
exec >$HOME/StackScript-$LINODE_ID-$(date +%Y-%m-%d).log 2>&1

# set the local timezone
export TZ=$TZ

echo "---> $0: start-run as $(whoami): $(date)"

echo "* setting up Linode ID: << $LINODE_ID >> [lish_user=$LINODE_LISHUSERNAME]"
echo "* linode DataCenter ID=$LINODE_DATACENTERID, linode RAM=$LINODE_RAM MB"

# P1: set hostname
echo && echo "* [$(date +%H:%M)] setting a hostname to something non-default"
HOSTNAME=localhost
OS_NAME=$(awk -F= '/^ID=/{print $2}' /etc/os-release)
OS_RELEASE=$(grep "VERSION_ID=" /etc/os-release | sed 's/.*="\([0-9]*\).*/\1/; s/"//g')
[ -n "$OS_NAME" ] && HOSTNAME=$OS_NAME
[ -n "$OS_RELEASE" ] && HOSTNAME="$HOSTNAME$OS_RELEASE"
[ $LINODE_DATACENTERID -eq 6 ] && HOSTNAME="nj-$HOSTNAME"
[ $LINODE_DATACENTERID -eq 15 ] && HOSTNAME="tor-$HOSTNAME"
echo "- setting hostname to: $HOSTNAME"
hostnamectl set-hostname $HOSTNAME

# P2: set timezone to LOCAL timezone
echo && echo "* [$(date +%H:%M)] setting timezone to '$TZ' timezone"
timedatectl set-timezone $TZ

# set env as non-interactive, to suppress errors in apt-get installation
export DEBIAN_FRONTEND="noninteractive"

# P3: run apt-get update
echo && echo "* [$(date +%H:%M)] update apt sources"
apt-get update -qq

# P3: install ZSH
echo && echo "* [$(date +%H:%M)] install+setup: zsh"
apt-get install -qq -y zsh

# P4: add a non-root user, with same PW as root
echo && echo "* [$(date +%H:%M)] add additional user: $LOCAL_USER"
if echo "$LOCAL_USER" | egrep -q '^[a-z][a-z]*$'; then
  PW_HASH=$(getent shadow $USER | cut -d: -f2 |head -1)
  [ -z "$PW_HASH" ] && exit 1
  echo "- adding $LOCAL_USER with existing PW hash"
  sudo useradd -m -p "$PW_HASH" $LOCAL_USER || exit 1
  echo "- changing shell for $LOCAL_USER to /bin/zsh"
  chsh -s /bin/zsh $LOCAL_USER || exit 1
  echo "- adding $LOCAL_USER to sudo group to allow sudo"
  usermod -aG sudo $LOCAL_USER || exit 1

  echo "- setting up $LOCAL_USER .ssh & homedir"
  U_HOME=/home/$LOCAL_USER
  echo "echo 'TO-SETUP-RUN: $ rm .zshrc && wget $WGET_URL && bash dl.sh'" > $U_HOME/.zshrc || exit 1
  chown -v $LOCAL_USER $U_HOME/.zshrc && chmod -v 666 $U_HOME/.zshrc
  mkdir $U_HOME/.ssh || exit 1
  cp -fv $HOME/.ssh/authorized_keys $U_HOME/.ssh/authorized_keys || exit 1
  chmod -v 700 $U_HOME/.ssh && chmod -v 600 $U_HOME/.ssh/authorized_keys || exit 1
  chown -v $LOCAL_USER $U_HOME/.ssh $U_HOME/.ssh/authorized_keys || exit 1
else
  echo "--WARN: invalid user << $LOCAL_USER >>, skipping..." >&2
fi

# P5: install fail2ban - to increase SSH security
echo && echo "* [$(date +%H:%M)] install+setup: fail2ban"
nice apt-get install -qq -y fail2ban
nice systemctl enable fail2ban
nice systemctl start fail2ban

### optional stuff (under `nice') ######################

# P6: install additional key packages
echo && echo "* [$(date +%H:%M)] install screen,tmux,sshpass"
nice apt-get install -qq -y screen tmux sshpass

echo && echo "* [$(date +%H:%M)] perform apt-get upgrade"
nice apt-get upgrade -y

echo "---> $0: finished-run as $(whoami): $(date)"

### Metadata ###########################################
#
# KW custom boot script - StackScript (runs as root)
# - sets a default hostname
# - sets up the system's timezone
# - does an apt-update
# - installs `zsh'
# - sets up a main user and adds to sudo group
# - installs fail2ban to help guard against SSH attacks
# - sets up key packages: screen/tmux/sshpass (under `nice')
# - performs an apt-upgrade to bring the system to the latest level (under `nice')

# EOF
