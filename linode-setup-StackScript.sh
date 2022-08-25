#!/bin/bash
# Linode setup StackScript for Debian/Ubuntu Linux

# enable logging
exec > $HOME/StackScript-$LINODE_ID-`date +%Y-%m-%d`.log 2>&1

# set the EDT timezone
export TZ="America/New_York"

echo "---> $0: start-run as `whoami`: `date`"

echo "* setting up Linode ID: << $LINODE_ID >> [lish_user=$LINODE_LISHUSERNAME]"
echo "* linode DataCenter ID=$LINODE_DATACENTERID, linode RAM=$LINODE_RAM MB"

# P1: get the dl.sh script, which we'll use later
echo && echo "* [`date +%H:%M`] downloading setup-script"
cd $HOME && mkdir src && cd src
wget -q http://kordy.com/dl.sh && chmod 755 dl.sh && mv dl.sh "bkup-and-transfer.sh"
#cd dl && wget -q http://www.kordy.com/example-scripts.tar.gz.gpg
cd && ln -s "./src/bkup-and-transfer.sh"
cd && mkdir bin && chmod 755 bin

# P1: set timezone to LOCAL timezone
echo && echo "* [`date +%H:%M`] setting timezone to Local timezone"
nice -n -5 timedatectl set-timezone America/New_York

# set env as non-interactive, to suppress errors in apt-get installation
export DEBIAN_FRONTEND="noninteractive"

# run apt-get update
echo && echo "* [`date +%H:%M`] update apt"
nice -n -5 apt-get update -qq

# install ZSH
echo && echo "* [`date +%H:%M`] install+setup: zsh"
nice -n -5 apt-get install -qq -y zsh

# install fail2ban - to increase SSH security
echo && echo "* [`date +%H:%M`] install+setup: fail2ban"
apt-get install -qq -y fail2ban

# add a non-root user
#useradd -m user
#chsh -s /bin/zsh user

### optional stuff (under `nice') ######################

# install additional key packages
echo && echo "* [`date +%H:%M`] install screen+sshpass+sysbench"
nice apt-get install -qq -y screen sshpass sysbench

echo && echo "* [`date +%H:%M`] perform apt-get upgrade"
nice apt-get upgrade -y

echo "---> $0: finished-run as `whoami`: `date`"

### Metadata ###########################################
#
# KW custom boot script - StackScript
# - does an apt-update
# - sets up timezone
# - downloads the main setup script
# - installs `zsh'
# - sets up key packages
# - optionally, sets up a user

# EOF
