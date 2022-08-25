#!/bin/bash
# KW Linode setup StackScript for Debian/Ubuntu Linux
#
# * By Kordian W. <code [at] kordy.com>, Aug 2022
#

##################################
# what local user to create?
LOCAL_USER="<USER>"

# name of the key setup script
WGET_URL="<URL>"
SETUP_SCRIPT="bkup-and-transfer.sh"

TZ="America/New_York"
##################################

# enable logging
exec > $HOME/StackScript-$LINODE_ID-`date +%Y-%m-%d`.log 2>&1

# set the local timezone
export TZ=$TZ

echo "---> $0: start-run as `whoami`: `date`"

echo "* setting up Linode ID: << $LINODE_ID >> [lish_user=$LINODE_LISHUSERNAME]"
echo "* linode DataCenter ID=$LINODE_DATACENTERID, linode RAM=$LINODE_RAM MB"

# P1: set hostname
echo && echo "* [`date +%H:%M`] setting a hostname to something non-default"
HOSTNAME=localhost
OS_NAME=`awk -F= '/^ID=/{print $2}' /etc/os-release`
OS_RELEASE=`grep "VERSION_ID=" /etc/os-release | sed 's/.*="\([0-9]*\).*/\1/'`
[ -n "$OS_NAME" ] && HOSTNAME=$OS_NAME
[ -n "$OS_RELEASE" ] && HOSTNAME="$HOSTNAME$OS_RELEASE"
[ $LINODE_DATACENTERID -eq 6 ]  && HOSTNAME="nj-$HOSTNAME"
[ $LINODE_DATACENTERID -eq 15 ] && HOSTNAME="tor-$HOSTNAME"
echo "- setting hostname to: $HOSTNAME"
hostnamectl set-hostname $HOSTNAME

# P2: get the dl.sh script, which we'll use later
echo && echo "* [`date +%H:%M`] downloading $SETUP_SCRIPT"
cd && mkdir src && cd src
if echo "$WGET_URL" | egrep -q '^http'; then
  wget -q "$WGET_URL" && chmod 755 dl.sh && mv dl.sh $SETUP_SCRIPT
  cd && ln -s "./src/$SETUP_SCRIPT"
  cd && ls -lh $SETUP_SCRIPT
  cd && mkdir bin && chmod 755 bin
else
  echo "--WARN: invalid URL << $WGET_URL >>, skipping..." >&2
fi

# P3: set timezone to LOCAL timezone
echo && echo "* [`date +%H:%M`] setting timezone to \'$TZ' timezone"
timedatectl set-timezone $TZ

# set env as non-interactive, to suppress errors in apt-get installation
export DEBIAN_FRONTEND="noninteractive"

# P4: run apt-get update
echo && echo "* [`date +%H:%M`] update apt sources"
apt-get update -qq

# P5: install ZSH
echo && echo "* [`date +%H:%M`] install+setup: zsh"
apt-get install -qq -y zsh

# P6: add a non-root user, with same PW as root
echo && echo "* [`date +%H:%M`] add additional user: $LOCAL_USER"
if echo "$LOCAL_USER" | egrep -q '^[a-z][a-z]*$'; then
  PW_HASH=$(getent shadow root | cut -d: -f2)
  [ -z "$PW_HASH" ] && exit 1
  echo "- adding $LOCAL_USER with existing PW hash"
  sudo useradd -m -p "$PW_HASH" $LOCAL_USER || exit 1
  echo "- changing shell for $LOCAL_USER to /bin/zsh"
  chsh -s /bin/zsh $LOCAL_USER || exit 1
  echo "- adding $LOCAL_USER to sudo group to allow sudo"
  usermod -aG sudo $LOCAL_USER || exit 1

  echo "- setting up $LOCAL_USER .ssh & homedir"
  U_HOME=/home/$LOCAL_USER
  mkdir $U_HOME/.ssh || exit 1
  cp -fv $HOME/.ssh/authorized_keys $U_HOME/.ssh/authorized_keys || exit 1
  chmod -v 700 $U_HOME/.ssh && chmod 600 $U_HOME/.ssh/authorized_keys || exit 1
  chown -v $LOCAL_USER $U_HOME/.ssh $U_HOME/.ssh/authorized_keys || exit 1
else
  echo "--WARN: invalid user << $LOCAL_USER >>, skipping..." >&2
fi

# install fail2ban - to increase SSH security
echo && echo "* [`date +%H:%M`] install+setup: fail2ban"
nice apt-get install -qq -y fail2ban
nice systemctl enable fail2ban
nice systemctl start fail2ban


### optional stuff (under `nice') ######################

# install additional key packages
echo && echo "* [`date +%H:%M`] install screen,sshpass,sysbench"
nice apt-get install -qq -y screen sshpass sysbench

echo && echo "* [`date +%H:%M`] perform apt-get upgrade"
nice apt-get upgrade -y

echo "---> $0: finished-run as `whoami`: `date`"


### Metadata ###########################################
#
# KW custom boot script - StackScript (runs as root)
# - does an apt-update
# - sets up timezone
# - downloads the main setup script
# - installs `zsh'
# - sets up key packages
# - sets up a user and adds to sudo group
# - sets a default hostname

# EOF
