#!/bin/bash
#
# Script to setup a Linux system, eg: install additional packages on a Linux machine
# - works on Ubuntu, Debian (incl. Mint), RHEL and Raspbian
#
# SETUP:   $ wget http://kordy.com/dl.sh && bash dl.sh
# HW-INFO: $ curl -s https://raw.githubusercontent.com/kordianw/HW-Info/master/hw-info.sh | bash
#
# * By Kordian W. <code [at] kordy.com>, Nov 2017
#

# default timezone (find using `tzselect' or `timedatectl list-timezones')
TZ="America/New_York"

#
# FUNCTIONS
#
function setup() {
  # what is the package manager to choose?
  if [ -x /usr/bin/apt -a -x /usr/bin/yum ]; then
    echo "$PROG: both \`apt' and \`get' are installed! can't choose the package manager!" >&2
    exit 99
  elif [ -x /usr/bin/apt ]; then
    PKG=apt
  elif [ -x /usr/bin/yum ]; then
    PKG=yum
  elif [ -x /usr/bin/zypper ]; then
    PKG=zypper
  else
    echo "$PROG: neither \`apt' or \`get' or \`zypper' are installed! can't choose the package manager!" >&2
    exit 99
  fi

  # do we need sudo?
  if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
  else
    SUDO=""
  fi

  # where is my SRC dir located?
  KW_SRC_DIR="$HOME/src"
  [ -d "$HOME/playground" ] && KW_SRC_DIR="$HOME/playground"
}

function check_root() {
  if [ "$EUID" -ne 0 ]; then
    sudo -n whoami >&/dev/null
    if [ $? -ne 0 ]; then
      echo "--FATAL: this script can only run with sudo/root privileges, \`$USER' doesn't have them!" 1>&2
      exit 99
    fi
  fi
}

function install_general_packages {
  #
  # TODO Mint Linux
  #
  # - boot Lenovo ThinkPad T480s from USB via "Enter,F12"
  # - change timezone
  #   * this script: -TZ param
  #   * /or/ alternatively, Start->Clock
  # - add percentage to battery panel (right click, properties)
  # - reverse the scroll direction (Start,Mouse/TouchPad)
  # - connect WIFI & Disable Bluetooth
  # - Start,Session Login & Startup - DISABLE:
  #   * blueberry, Bluetooth, mintwelcome
  #   * screen locker, system reports, update manager
  # - configure Start,Software Sources to choose fastest mirrors
  # - disable screensaver (Start: Display, then Power)
  #   * this allows proper suspend on lid close
  #   * NB: test that Suspend works properly on lid close
  # - change Close Window from Alt-F4 to Ctrl-Q and Ctrl-Win+UP to maximize
  #   * Start,Window Manager,Keyboard
  #   * change Alt-F4 to Ctrl-Q
  #   * change Maximize Window to Ctrl-Super-UP
  # - allow Alt-Space to start programs
  #   * Start,Keyboard,Application Shortcuts
  #   * ADD: `xfce4-appfinder' and assign to Alt-Space (ignore warning)
  # - add Terminal to startup
  #   * Start->Session/Startup, add xfce4-terminal as an executable
  # - change Terminal settings:
  #   * default settings to 200x50
  #   * in Advanced, "automatically copy selection to clipboard
  #
  # CLI
  # - install `src' playground with all the scripts
  #   * install packages via this script
  #   * install SSH via this script (CAREFUL)
  # - LOGIN REMOTELY via ssh: ssh t480s
  #   * copy Config files
  # - ZSH -> this script with -ZSH param
  # - install optional packages, such as VLC, Chrome, Remmina
  #   * later, restore Remmina settings/sessions
  #   * in Remmina, add the following 16:9 resolutions: 1440x810 & 1600x900
  # - set-up Downloads area:
  #   # rmdir ~/Downloads
  #   # create-one-file-fs.sh /cdrom/Downloads-rw 4095M /home/mint/Downloads
  #   # add to /etc/fstab: /cdrom/Downloads-rw /home/mint/Downloads vfat loop,rw,relatime,user,uid=999,gid=999 0 0
  # - reduce the SYSLOG spam from `sysstat'
  #   # sudo vi /etc/cron.d/sysstat
  #   -> comment out all the cron-entries
  # - copy from backup, eg: Chrome/Firefox, Remmina settings
  #

  # record start-time
  START_TIME=$(date "+%s")

  [ "$OSTYPE" != "linux-gnu" -a "$OSTYPE" != "linux" ] && {
    echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnu >>!" >&2
    exit 2
  }
  [ ! -r /etc/os-release ] && {
    echo "$PROG: no /etc/os-release file, is this really Linux ?" >&2
    exit 3
  }

  # setup program & vars
  setup
  check_root

  # -y=yes, -q=quiet
  if [ "$PKG" = "apt" ]; then
    INSTALL_CMD="$SUDO apt-get install -qq -y"
  elif [ "$PKG" = "yum" ]; then
    INSTALL_CMD="$SUDO yum -y install"
  else
    echo "can't select package manager!"
    exit 1
  fi

  # update the local database to make sure it matches remote sources
  if [ "$PKG" = "apt" ]; then
    echo "* updating the apt local database..."
    $SUDO apt update
  elif [ "$PKG" = "yum" ]; then
    echo "* refreshing the package index..."
    $SUDO yum check-update
  fi

  # apps
  echo && echo "* GENPKG: installing packages..."

  # GENPKG: major packages - CLI & GUI
  $INSTALL_CMD vim # VIM: improved vi (VI iMproved)
  $INSTALL_CMD zsh # the Z Shell (more powerful than bash)

  # GENPKG: GUI Packages
  if who | grep $USER | grep tty | grep -q ":0"; then
    echo -e "\n***\n*** GENPKG: INSTALLING GUI PKGS\n***\n"
    $INSTALL_CMD chromium-browser
    $INSTALL_CMD vlc
    $INSTALL_CMD remmina
    $INSTALL_CMD remmina-plugin-rdp
    $INSTALL_CMD remmina-plugin-vnc
    $INSTALL_CMD xdotool
    $INSTALL_CMD boot-repair # Graphical tool to repair boot problems
  fi

  # GENPKG: Laptop specific tools
  if [ -f /sys/module/battery/initstate -o -d /proc/acpi/battery/BAT0 -o -L /sys/class/power_supply/BAT0 ]; then
    echo -e "\n***\n*** GENPKG: INSTALLING LAPTOP PKGS\n***\n"
    $INSTALL_CMD acpi         # view battery/ACPI information (LAPTOPS)
    $INSTALL_CMD acpitool     # view battery/ACPI information (LAPTOPS)
    $INSTALL_CMD wavemon      # wireless Device Monitoring Application (LAPTOPS)
    $INSTALL_CMD powertop     # diagnose issues with power consumption and management (LAPTOPS)
    $INSTALL_CMD cpufrequtils # utilities to deal with the cpufreq Linux kernel feature
    $INSTALL_CMD caffeine     # prevent the desktop becoming idle in full-screen mode
  fi

  # GENPKG: Mail
  #$INSTALL_CMD postfix      # this allows mail to be delivered
  #$INSTALL_CMD mailutils    # this allows mail to be delivered
  #$INSTALL_CMD mutt         # more friendly mail client
  #$INSTALL_CMD procmail     # could be useful
  #$INSTALL_CMD libsasl2-modules  # needed for sendgrid/external SMTP

  # GENPKG: terminal multipliers
  $INSTALL_CMD screen # GNU screen
  $INSTALL_CMD tmux   # GNU tmux

  # text-based browsers
  $INSTALL_CMD lynx  # classic non-graphical (text-mode) web browser
  $INSTALL_CMD links # Web browser running in text mode
  #$INSTALL_CMD w3m           # WWW browsable pager with excellent tables/frames support

  # GENPKG: development
  $INSTALL_CMD git # github/git
  $INSTALL_CMD jq  # lightweight and flexible command-line JSON processor
  #$INSTALL_CMD s3cmd         # S3 client
  #$INSTALL_CMD rclone        # cloud upload/download client
  #$INSTALL_CMD ansible       # Ansible
  #$INSTALL_CMD awscli        # AWS CLI

  # GENPKG: compiling / gcc
  $INSTALL_CMD build-essential
  $INSTALL_CMD gcc        # GNU compiler
  $INSTALL_CMD libc6-dev  # LIBC dev headers
  $INSTALL_CMD automake   # automake
  $INSTALL_CMD pkg-config # pkg-config
  $INSTALL_CMD openssl    # SSL
  $INSTALL_CMD libssl-dev # SSL libraries
  $INSTALL_CMD libncurses5-dev libncursesw5-dev

  # GENPKG: additional perl modules
  #$INSTALL_CMD libjson-perl        # JSON.pm
  #$INSTALL_CMD libdate-manip-perl  # DateManip.pm
  #$INSTALL_CMD libxml-sax-perl     # for XML parsing (faster)
  #$INSTALL_CMD libxml-parser-perl  # for XML parsing (faster)

  # GENPKG: PYTHON 3
  $INSTALL_CMD python3
  $INSTALL_CMD python3-pip

  # GENPKG: additional PYTHON modules
  #$INSTALL_CMD pylint
  #$INSTALL_CMD python-flask
  #$INSTALL_CMD python-boto

  # GENPKG: system utils (may require cron-entries)
  #$INSTALL_CMD sysstat       # install stat utils such as sar, iostat, etc
  #$INSTALL_CMD mlocate       # quickly find files on the filesystem based on their name
  [ -x /usr/bin/apt ] && $INSTALL_CMD apt-file # search for files within Debian packages (CLI)

  # GENPKG: system utils (do not require cron)
  #$INSTALL_CMD neofetch      # Shows Linux System Information with Distribution Logo
  #$INSTALL_CMD inxi          # full featured system information script
  #$INSTALL_CMD lshw          # information about hardware configuration, incl. lspci
  #$INSTALL_CMD hwinfo        # Hardware identification system
  #$INSTALL_CMD cpuid         # tool to dump x86 CPUID information about the CPU(s)
  $INSTALL_CMD dmidecode # active/passive network address scanner using ARP requests
  #$INSTALL_CMD hdparm        # tune hard disk parameters for high performance
  $INSTALL_CMD sysbench   # multi-threaded benchmark tool
  $INSTALL_CMD lsof       # Utility to list open files
  $INSTALL_CMD ncdu       # Disk usage analysis
  $INSTALL_CMD bind-utils # tools such as `dig'

  # GENPKG: network & security tools
  $INSTALL_CMD telnet    # telnet for checking connectivity
  $INSTALL_CMD dnsutils  # provides dig+nslookup
  $INSTALL_CMD net-tools # provides ifconfig
  #$INSTALL_CMD netcat        # TCP/IP swiss army knife
  $INSTALL_CMD nmap # The Network Mapper/Scanner
  #$INSTALL_CMD sshfs         # filesystem client based on SSH File Transfer Protocol
  #$INSTALL_CMD netdiscover   # SMBIOS/DMI table decoder
  $INSTALL_CMD ntpdate # one-off synchronize clock with a remote NTP server
  $INSTALL_CMD ntpstat # show network time protocol (ntp) status
  #$INSTALL_CMD ethtool       # display or change Ethernet device settings
  #$INSTALL_CMD aircrack-ng   # wireless WEP/WPA cracking utilities
  $INSTALL_CMD sshpass # Non-interactive ssh password authentication

  # GENPKG: small utils (just helper utils)
  $INSTALL_CMD tofrodos # unix2dos, dos2unix
  $INSTALL_CMD bc       # CLI calculator
  #$INSTALL_CMD par           # advanced Paragraph reformatter (can be used inside vim)
  #$INSTALL_CMD pydf          # colourised df(1)-clone
  $INSTALL_CMD htop # improved `top'

  if [ "$PKG" = "apt" ]; then
    # update the apt-file utility
    echo && echo "* GENPKG: updating the apt-file cache..."
    $SUDO apt-file update

    # store a backup of currently installed packages
    echo && echo "* GENPKG: storing a backup of all installed packages..."
    DIR=$(dirname "$0")
    dpkg -l >$DIR/pkg-installed-list.txt
  fi

  # GENPKG: show end time
  END_TIME=$(date +%s)
  TIME_TAKEN=$(($END_TIME - $START_TIME))
  if [ $TIME_TAKEN -gt 60 ]; then
    TIME_TAKEN=$(echo "($END_TIME - $START_TIME) / 60" | bc -l | sed 's/\(...\).*/\1/')
    echo "  <<< Time taken: $TIME_TAKEN min(s) @ $(date +%H:%M) >>>" 1>&2
  fi
}

function change_timezone() {
  # setup program & vars
  setup
  check_root

  # check we know what TZ we're going to
  [ -z "$TZ" ] && {
    echo "$PROG: no TZ variable set!" >&2
    exit 1
  }

  # check that TZ selected exists
  if ! ls -l /usr/share/zoneinfo/$TZ; then
    echo "$PROG: the TZ \'$TZ' doesn't seem to exist?" >&2
    exit 3
  fi

  # check for /etc/timezone, unless on Fedora
  if [ ! -s /etc/timezone ]; then
    echo "$PROG: seems like RHEL/Fedora Linux, which has no /etc/timezone, skipping check..." >&2
  else
    # this system has no /etc/timezone - not sure if this process would work
    if [ ! -e /etc/timezone ]; then
      echo "$PROG: this system has no \`/etc/timezone' - not sure that this process would work?" >&2
      exit 2
    fi

    # not supporting certain set-ups
    [ -L /etc/timezone ] && {
      echo "$PROG: not supporting linked /etc/timezone!" >&2
      exit 1
    }

    echo "* viewing contents of current /etc/timezone:"
    cat /etc/timezone || exit 1
  fi

  echo "* viewing contents of current /etc/timezone and /etc/localtime link:"
  [ ! -e /etc/localtime ] && {
    echo "$PROG: not supporting absense of /etc/localtime!" >&2
    exit 1
  }

  # special case for Amazon Linux
  if grep -q "Amazon Linux" /etc/os-release; then
    [ -f /etc/localtime ] || {
      echo "$PROG: not supporting non-existing file /etc/localtime on Amazon Linux!" >&2
      exit 1
    }
  else
    [ -L /etc/localtime ] || {
      echo "$PROG: not supporting non-linked /etc/localtime!" >&2
      exit 1
    }
  fi
  ls -l /etc/localtime || exit 2

  # SPECIAL CASE FOR NYC/US Eastern
  CHECK_TZ="$TZ"
  [ "$CHECK_TZ" = "America/New_York" -o "$CHECK_TZ" = "US/Eastern" ] && CHECK_TZ="America/New_York|US/Eastern"

  # do we need to do anything???
  if ls -l /etc/localtime | egrep -q "$CHECK_TZ"; then
    echo -e "\n$PROG: check 1: according to /etc/localtime (#1), this system TZ is already set to $TZ - good, nothing to do:" >&2
    ls -l /etc/localtime || exit 1

    if egrep -q "$CHECK_TZ" /etc/timezone; then
      echo -e "\n$PROG: check 2: according to /etc/timezone (#2), this system TZ is already set to $TZ - good, nothing to do:" >&2
      cat /etc/timezone || exit 2
    fi

    if which timedatectl >&/dev/null; then
      echo && echo "* running \`timedatectl status' - check for sync:"
      timedatectl status || exit 3
    fi

    exit 0
  fi

  # fall-back
  if [ -e /etc/timezone ]; then
    if egrep -q "$CHECK_TZ" /etc/timezone; then
      echo -e "\n$PROG: according to /etc/timezone, this system TZ is already set to $TZ - nothing to do:" >&2
      cat /etc/timezone || exit 1
      ls -l /etc/localtime || exit 2

      exit 0
    fi
    echo
    echo "** no /etc/timezone exists on this system ..." 1>&2
  fi

  # additional checks using timedatectl
  if which timedatectl >&/dev/null; then

    # check that this works
    timedatectl list-timezones >&/dev/null
    if [ $? -eq 0 ]; then
      # check that valid
      if [ $(timedatectl list-timezones | grep -c $TZ) -ne 1 ]; then
        echo "$PROG: the TZ \'$TZ' doesn't seem to be valid?" >&2
        exit 4
      fi

      # check whether we're already there...
      CURRENT_TZ=$(timedatectl status | awk '/Time zone/{print $3}')
      [ -z "$CURRENT_TZ" ] && {
        echo "$PROG: can't get current system's TZ via timedatectl status!" >&2
        exit 1
      }

      if [ "$CURRENT_TZ" = "$TZ" ]; then
        echo "$PROG: according to \`timedatectl -status', this system TZ is already set to $TZ - nothing to do." >&2
        exit 0
      fi
    else
      echo && echo "$PROG: the: \`timedatectl list-timezones' is not working on this host:" >&2
      timedatectl list-timezones
      echo && echo "...if everything fails, try setting the TZ manually via: \"export TZ=$TZ\"" >&2
    fi

  fi

  # which method of change?
  if which dpkg-reconfigure >&/dev/null; then
    #
    # CHANGE
    #
    echo -e "\n*** changing system's timezone to: $TZ\n- before: $(date)"
    #set -x
    #echo "$TZ" | $SUDO tee /etc/timezone || exit 1
    #sudo dpkg-reconfigure --frontend noninteractive tzdata
    #set +x

    if [ -e /etc/localtime -a -e /usr/share/zoneinfo/America/New_York ]; then
      # method 1
      #echo 'tzdata tzdata/Areas select Europe' | debconf-set-selections
      #echo 'tzdata tzdata/Zones/Europe select New_York' | debconf-set-selections
      #DEBIAN_FRONTEND="noninteractive" apt-get install -y tzdata

      # method 2
      export DEBIAN_FRONTEND=noninteractive
      $SUDO ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
      $SUDO dpkg-reconfigure --frontend noninteractive tzdata

      RC=$?
    fi

    # try another way ... probably interactive
    if [ -z "$RC" -o $RC -ne 0 ]; then
      unset DEBIAN_FRONTEND
      $SUDO dpkg-reconfigure tzdata
    fi

    # confirm
    echo "- now:   $(date)"

  elif which timedatectl >&/dev/null; then
    #
    # CHANGE
    # - this works on RHEL or Fedora
    #
    echo -e "\n* executing: \`$SUDO timedatectl set-timezone $TZ' as fall-back due to dpkg-reconfigure not there:"
    $SUDO timedatectl set-timezone $TZ

  else
    echo "$PROG: no \`timedatectl' and no \`dpkg-reconfigure' binary on the current system - can't change timezone" >&2
    exit 1
  fi

  # confirm
  if [ -s /etc/timezone ]; then
    echo && echo "* viewing contents of updated /etc/timezone and /etc/localtime link:"
    cat /etc/timezone || exit 1
  fi

  echo && echo "* viewing contents of updated /etc/localtime link:"
  ls -l /etc/localtime || exit 2

  if which timedatectl >&/dev/null; then
    echo && echo "* running \`timedatectl status' - check for sync:"
    timedatectl status
  else
    echo && echo "* no \`timedatectl status' - can't work out final TZ status..."
  fi
}

function enable_setup_zsh() {
  # setup program & vars
  setup

  # make sure we have USER defined
  if [ -z "$USER" ]; then
    echo "$PROG: can't work out the current USER via USER shell var!" >&2
    exit 1
  fi

  # check for ZSH
  ZSH=$(chsh -l 2>/dev/null | grep zsh | tail -1)
  [ -z "$ZSH" ] && ZSH=$(which zsh 2>/dev/null)
  [ "$ZSH" = "/usr/bin/zsh" -a -x "/bin/zsh" ] && ZSH="/bin/zsh"

  # is ZSH available?
  if [ -z "$ZSH" ]; then
    # not avail - can we install?
    if [ "$EUID" -eq 0 ]; then
      # install
      echo "$PROG: installing \`zsh': $SUDO $PKG install -qq -y zsh..." >&2
      $SUDO $PKG install -qq -y zsh

      # try again after doing an update
      if [ $? -ne 0 -a "$PKG" = "apt" ]; then
        echo "... trying again after doing an \`apt-get update'" >&2
        $SUDO apt-get update
        $SUDO $PKG install -qq -y zsh
      fi
    else
      sudo -n whoami >&/dev/null
      if [ $? -eq 0 ]; then
        # install
        echo "$PROG: installing \`zsh': $SUDO $PKG install -qq -y zsh..." >&2
        $SUDO $PKG install -qq -y zsh

        # try again after doing an update
        if [ $? -ne 0 -a "$PKG" = "apt" ]; then
          echo "... trying again after doing an \`apt-get update'" >&2
          $SUDO apt-get update
          $SUDO $PKG install -qq -y zsh
        fi
      else
        echo -e "$PROG: The zsh SHELL is not available/installed & can't be auto-installed: run\n# $SUDO $PKG install zsh" >&2
        echo "-> error: can't get sudo working non-interactively:" >&2
        sudo -n whoami

        exit 4
      fi
    fi
  else
    echo "$PROG: Found the ZSH as \`$ZSH' ..." >&2
  fi

  # after potential installation - check for ZSH
  ZSH=$(chsh -l 2>/dev/null | grep zsh | tail -1)
  [ -z "$ZSH" ] && ZSH=$(which zsh 2>/dev/null)

  # Failure...
  if [ -z "$ZSH" ]; then
    echo -e "$PROG: The zsh SHELL is not available/installed & can't be auto-installed: run\n# $SUDO $PKG install zsh" >&2
    exit 4
  fi

  # do we already have it set?
  if getent passwd $USER | grep -q ":$ZSH"; then
    echo "$PROG: your user's < $USER > shell is already: $ZSH - nothing to do!" >&2
    exit 0
  fi

  # make sure it's in /etc/shells
  if ! grep -q "^$ZSH$" /etc/shells; then
    echo "$PROG: the shell \`$ZSH' - is not in /etc/shells - this means can't change!" >&2
    exit 6
  fi

  # don't change shell for `root'
  if [ "$USER" = "root" ]; then
    echo "--WARN: handled ZSH installation, but don't recommend changing shell for \`root', ENDING script!"
    exit 1
  fi

  if [ "$USER" = "ubuntu" -o "$USER" = "ec2-user" ]; then
    echo && echo "*** NB: this user is \"$USER\", consider keeping current shell and create another user w/ZSH for daily use..." >&2
    echo -e "-----> Would you still like to change \"$USER\" default shell to ZSH? [y/N] \c"
    read CONF
    if [ "$CONF" = "y" -o "$CONF" = "Y" ]; then
      echo "--WARN: handled ZSH installation, and will now change default shell for \`$USER' to ZSH"
    else
      echo "--WARN: handled ZSH installation, but don't recommend changing shell for \`$USER', ENDING script!"
      exit 1
    fi
  fi

  # make sure we have ZSHRC installed
  if [ ! -r $HOME/.zshrc ]; then
    echo "$PROG: create a \`$HOME/.zshrc' file before changing the shell!" >&2
    exit 7
  else
    echo "$PROG: found \`$HOME/.zshrc', proceeding to change shell to: $ZSH..." >&2
  fi

  # is chsh available? (not available on Amazon Linux)
  if ! which chsh >&/dev/null; then
    echo "$PROG: \`chsh' is not available on this system ... trying to install" 1>&2
    check_root
    OS=$(awk -F= '/^NAME=/{print $NF}' /etc/os-release)

    # various Linux -> installs csh
    if echo "$OS" | egrep -q "Amazon Linux|Fedora|CentOS|RHEL|Rocky"; then
      $SUDO yum -y -qq install util-linux-user
    elif [ -x /usr/bin/yum ]; then
      $SUDO yum -y -qq install util-linux-user
    fi
  fi

  #
  # EXEC
  #
  echo "+ $SUDO chsh -s $ZSH $USER"
  $SUDO -n chsh -s $ZSH $USER

  if [ $? -ne 0 ]; then
    echo "+ chsh -s $ZSH"
    chsh -s $ZSH
  fi
}

function enable_ssh() {
  check_root

  [ "$OSTYPE" != "linux-gnu" -a "$OSTYPE" != "linux" ] && {
    echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnu >>!" >&2
    exit 2
  }
  [ ! -r /etc/os-release ] && {
    echo "$PROG: no /etc/os-release file, is this really Linux ?" >&2
    exit 3
  }
  [ ! -x /usr/bin/apt ] && {
    echo "$PROG: can't find/exec APT!" >&2
    exit 4
  }

  # do we need to install it? maybe it's already installed...
  if [ -e /usr/sbin/sshd -a -e /etc/init.d/ssh ]; then
    echo "* SSHD already installed: not installing openssh-server"
  else
    echo "* installing: openssh-server"
    $SUDO apt-get install -qq -y openssh-server
  fi

  if [ "$USER" = "mint" ]; then
    echo "* disabling: ssh from auto-restarting (OPTIONAL)"
    $SUDO systemctl disable ssh.service
  fi

  echo "* starting ssh service"
  $SUDO systemctl start ssh.service

  echo "* check-status: systemctl status ssh"
  $SUDO systemctl status ssh

  if [ "$USER" = "mint" ]; then
    echo && echo "* NOTE: in Mint Linux, default user \`mint' has no password, therefore need to add to \`/etc/ssh/sshd_config':"
    echo "PermitEmptyPasswords yes"
    echo && echo "# sudo vi /etc/ssh/sshd_config"
    echo "# systemctl restart ssh.service"
  fi
}

function disable_ssh() {
  check_root

  [ "$OSTYPE" != "linux-gnu" -a "$OSTYPE" != "linux" ] && {
    echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnu >>!" >&2
    exit 2
  }
  [ ! -r /etc/os-release ] && {
    echo "$PROG: no /etc/os-release file, is this really Linux ?" >&2
    exit 3
  }
  [ ! -x /usr/bin/apt ] && {
    echo "$PROG: can't find/exec APT!" >&2
    exit 4
  }

  echo "* disabling: ssh from auto-restarting"
  $SUDO systemctl disable ssh.service

  echo "* shutdown-server systemctl stop ssh"
  $SUDO systemctl stop ssh.service

  echo "* killing off ssh sessions"
  $SUDO killall sshd

  echo "* remove pkg: openssh-server"
  $SUDO apt remove -qq -y openssh-server

  echo "* remove pkg: openssh-sftp-server"
  $SUDO apt remove -qq -y openssh-sftp-server
}

function install_brew() {
  if [[ "$OSTYPE" != darwin* ]]; then
    echo "$PROG: invalid arch << $OSTYPE >>, expecting << darwin* >>! >&2"
    exit 2
  fi

  # install if necessary
  if ! which brew >&/dev/null; then
    echo "$PROG: installing \`brew.sh' - enter sudo password:"
    sleep 1
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

    if [ $? -ne 0 ]; then
      echo "--FATAL: issue installing brew!" >&2
    fi
  fi

  INSTALL_CMD="brew install"

  # update the local database to make sure it matches remote sources
  echo "* BREW: updating the brew database..."
  brew update

  # apps
  echo && echo "* BREW: installing packages..."

  # BREW: packages
  $INSTALL_CMD coreutils
  $INSTALL_CMD wget
  $INSTALL_CMD tmux
  $INSTALL_CMD links
  $INSTALL_CMD jq
  $INSTALL_CMD nmap
  #$INSTALL_CMD cask    # allow install via: brew cask install google-chrome

  # BREW: utils
  $INSTALL_CMD watch
  $INSTALL_CMD ncdu
  $INSTALL_CMD htop
  $INSTALL_CMD sysbench
  $INSTALL_CMD inxi
  $INSTALL_CMD mackup

  # BREW: compiler & tools
  $INSTALL_CMD gcc
  $INSTALL_CMD autoconf
  $INSTALL_CMD automake
  $INSTALL_CMD make
  $INSTALL_CMD cmake
  $INSTALL_CMD glib
  $INSTALL_CMD pkg-config

  # BREW: install `sshpass'
  #brew install http://git.io/sshpass.rb
  brew install https://raw.githubusercontent.com/kadwanev/bigboybrew/master/Library/Formula/sshpass.rb

  # BREW: list outdated packages and what would be the cleanup
  $INSTALL_CMD cleanup -n
  $INSTALL_CMD outdated
}

function install_pi() {
  # RASPBIAN PI

  check_root
  [ "$OSTYPE" != "linux-gnu" -a "$OSTYPE" != "linux" ] && {
    echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnueabihf >>!" >&2
    exit 2
  }
  [ ! -r /etc/os-release ] && {
    echo "$PROG: no /etc/os-release file, is this really Linux ?" >&2
    exit 3
  }
  [ ! -x /usr/bin/apt ] && {
    echo "$PROG: can't find/exec APT!" >&2
    exit 4
  }

  # -y=yes, -q=quiet
  INSTALL_CMD="sudo apt-get install -qq -y"

  # update the local database to make sure it matches remote sources
  echo "* PI: updating the apt local database..."
  sudo apt update

  # apps
  echo && echo "* PI: installing packages..."

  # PI: major packages
  $INSTALL_CMD vim # VIM: improved vi (VI iMproved)
  $INSTALL_CMD zsh # the Z Shell (more powerful than bash)

  # PI: terminal multipliers
  $INSTALL_CMD screen # GNU screen
  $INSTALL_CMD tmux   # GNU tmux

  # PI: text-based browsers
  $INSTALL_CMD lynx  # classic non-graphical (text-mode) web browser
  $INSTALL_CMD links # Web browser running in text mode
  #$INSTALL_CMD w3m           # WWW browsable pager with excellent tables/frames support

  # development
  $INSTALL_CMD git # github/git
  $INSTALL_CMD jq  # lightweight and flexible command-line JSON processor

  # PI: additional perl modules
  #$INSTALL_CMD libjson-perl  # JSON.pm

  # PI: PYTHON 3
  #$INSTALL_CMD python3
  #$INSTALL_CMD python3-pip

  # PI: additional python modules
  #$INSTALL_CMD pylint
  #$INSTALL_CMD python-flask
  #$INSTALL_CMD python-boto

  # PI: system utils (may require cron-entries)
  $INSTALL_CMD apt-file # search for files within Debian packages (CLI)
  $INSTALL_CMD sysstat  # install stat utils such as sar, iostat, etc
  $INSTALL_CMD mlocate  # quickly find files on the filesystem based on their name

  # PI: system utils (do not require cron)
  #$INSTALL_CMD neofetch      # Shows Linux System Information with Distribution Logo
  #$INSTALL_CMD inxi          # full featured system information script
  #$INSTALL_CMD lshw          # information about hardware configuration, incl. lspci
  #$INSTALL_CMD hwinfo        # Hardware identification system
  #$INSTALL_CMD cpuid         # tool to dump x86 CPUID information about the CPU(s)
  $INSTALL_CMD dmidecode # active/passive network address scanner using ARP requests
  #$INSTALL_CMD hdparm        # tune hard disk parameters for high performance
  $INSTALL_CMD sysbench   # multi-threaded benchmark tool
  $INSTALL_CMD lsof       # Utility to list open files
  $INSTALL_CMD ncdu       # Disk usage analysis
  $INSTALL_CMD bind-utils # tools such as `dig'

  # PI: network & security tools
  $INSTALL_CMD telnet    # telnet for checking connectivity
  $INSTALL_CMD dnsutils  # provides dig+nslookup
  $INSTALL_CMD net-tools # provides ifconfig
  #$INSTALL_CMD netcat        # TCP/IP swiss army knife
  $INSTALL_CMD nmap # The Network Mapper/Scanner
  #$INSTALL_CMD sshfs       # filesystem client based on SSH File Transfer Protocol
  #$INSTALL_CMD netdiscover # SMBIOS/DMI table decoder
  $INSTALL_CMD ntpdate # one-off synchronize clock with a remote NTP server
  $INSTALL_CMD ntpstat # show network time protocol (ntp) status
  #$INSTALL_CMD ethtool       # display or change Ethernet device settings
  #$INSTALL_CMD aircrack-ng   # wireless WEP/WPA cracking utilities
  $INSTALL_CMD sshpass # Non-interactive ssh password authentication

  # PI: small utils (just helper utils)
  $INSTALL_CMD tofrodos # unix2dos, dos2unix
  $INSTALL_CMD bc       # CLI calculator
  #$INSTALL_CMD par      # advanced Paragraph reformatter (can be used inside vim)
  #$INSTALL_CMD pydf          # colourised df(1)-clone
  $INSTALL_CMD htop # improved `top'

  # update the apt-file utility
  echo && echo "* updating the apt-file cache..."
  $SUDO apt-file update

  # store a backup of currently installed packages
  echo && echo "* storing a backup of all installed packages..."
  DIR=$(dirname "$0")
  dpkg -l >$DIR/pkg-installed-list.txt
}

function install_rhel() {
  # RED HAT LINUX / CENT OS LINUX / FEDORA LINUX

  check_root

  # record start-time
  START_TIME=$(date "+%s")

  [ "$OSTYPE" != "linux-gnu" -a "$OSTYPE" != "linux" ] && {
    echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnu >>!" >&2
    exit 2
  }
  [ ! -r /etc/redhat-release ] && {
    echo "$PROG: no /etc/redhat-release file, is this really RHEL ?" >&2
    exit 3
  }
  [ ! -x /usr/bin/yum ] && {
    echo "$PROG: can't find/exec YUM, eg for: yum install!" >&2
    exit 4
  }

  # RHEL: prepare
  sudo yum makecache

  # RHEL: MAJOR packages
  sudo yum -y install s3cmd.noarch # S3CMD - S3 CLI
  #sudo yum -y install ansible                # Ansible
  #sudo yum -y install awscli

  # RHEL: TERMINAL
  sudo yum -y install screen # GNU screen
  sudo yum -y install tmux   # TMUX

  # RHEL: WEB BROWSING
  sudo yum -y install links # text-based web-browser #1
  sudo yum -y install lynx  # text-based web-browser #2

  # RHEL: MAIL
  sudo yum -y install mutt  # allow better command line mail
  sudo yum -y install mailx # send cmd line mail

  # RHEL: DEVEL
  sudo yum -y install vim # editor of choice
  sudo yum -y install perl
  sudo yum -y install python
  sudo yum -y install python-pip
  sudo yum -y install python3
  sudo yum -y install python3-pip
  sudo yum -y install git    # GIT/GITHUB access
  sudo yum -y install jq     # lightweight and flexible command-line JSON processor
  sudo yum -y install strace # debug running processes
  sudo yum -y install wget

  # RHEL: COMPILING
  sudo yum -y install gcc           # GNU compiler
  sudo yum -y install automake      # automake
  sudo yum -y install openssl       # SSL
  sudo yum -y install openssl-devel # SSL libraries
  sudo yum -y install libtool       # libtool
  sudo yum -y install pkgconfig     # pkgconfig

  # RHEL: SHELLS
  sudo yum -y install zsh  # Z-Shell: my favourite shell
  sudo yum -y install tcsh # allow CSH for copy/paste purposes

  # RHEL: UTILS
  sudo yum -y install nfs-utils # NFS mount, showmount, etc
  sudo yum -y install wget
  sudo yum -y install curl
  sudo yum -y install zip        # installs ZIP support
  sudo yum -y install tar        # installs tar support
  sudo yum -y install unzip      # installs ZIP support (unzip)
  sudo yum -y install bzip2      # installs bzip2 support
  sudo yum -y install rsync      # GNU rsync
  sudo yum -y install tofrodos   # installs unix2dos/dos2unix
  sudo yum -y install bind-utils # nslookup/host/git/dig
  sudo yum -y install telnet
  sudo yum -y install nc        # ncat/netcat
  sudo yum -y install bc        # calculator
  sudo yum -y install sharutils # uuencode/uudecode
  sudo yum -y install finger    # allow: finger username
  sudo yum -y install words     # database of common English words
  sudo yum -y install sshpass   # non-interactive SSH
  sudo yum -y install mlocate   # locate DB (fast `find')
  sudo yum -y install lshw      # HW list + monitor
  sudo yum -y install hwinfo    # HW list + monitor
  sudo yum -y install cpuid     # HW list + monitor
  sudo yum -y install inxi      # HW list + monitor
  sudo yum -y install neofetch
  sudo yum -y install bind-utils

  # RHEL: get the EPEL repository
  sudo yum -y install epel-release
  #wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-10.noarch.rpm
  #sudo rpm -ihv epel-release-7-10.noarch.rpm

  sudo yum -y install htop     # better version of `top'
  sudo yum -y install sysbench # basic system benchmark

  # PERL: additional Perl modules (if working with Perl a lot)
  sudo yum -y install perl-LWP-UserAgent-Determined

  sudo yum -y install perl-XML-Simple # for XML parsing
  sudo yum -y install perl-JSON       # for JSON parsing
  # need to have XML::SAX & XML::Parser installed, and ParserDetails.ini needs to exist
  sudo yum -y install libxml-sax-perl    # for XML parsing (faster)
  sudo yum -y install libxml-parser-perl # for XML parsing (faster)

  sudo yum -y install perl-DBI
  sudo yum -y install perl-DBD-MySQL

  # PERL: optional: other misc modules (these can be installed locally)
  sudo yum -y install perl-Data-Dumper
  sudo yum -y install perl-Mail-Sender
  sudo yum -y install perl-DateTime
  sudo yum -y install perl-Date-Calc
  sudo yum -y install perl-Mozilla-CA # for SSL handling

  # do we have hostname?
  if ! which hostname >&/dev/null; then
    sudo yum -y install bind-utils
    sudo yum -y install hostname
  fi

  # try to install SYSBENCH
  # - use a custom yum repository
  if ! which sysbench >&/dev/null; then
    curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.rpm.sh | sudo bash
    sudo yum -y install sysbench
  fi

  # show end time
  END_TIME=$(date +%s)
  TIME_TAKEN=$(($END_TIME - $START_TIME))
  if [ $TIME_TAKEN -gt 60 ]; then
    TIME_TAKEN=$(echo "($END_TIME - $START_TIME) / 60" | bc -l | sed 's/\(...\).*/\1/')
    echo "  <<< Time taken: $TIME_TAKEN min(s) @ $(date +%H:%M) >>>" 1>&2
  fi
}

function create_user() {
  setup
  check_root

  USER="$1"
  if [ -n "$USER" ]; then
    if grep -q "$USER:" /etc/passwd; then
      echo "*** user << $USER >> already exists ..."

      # was the password already set?
      if [[ $($SUDO passwd --status "$USER" | awk '{print $2}') = NP ]]; then
        echo "*** setting passwd for $USER"
        $SUDO passwd $USER

        if [ $? -ne 0 ]; then
          echo && echo "*** NB: TRY AGAIN #1: setting passwd for $USER" >&2
          $SUDO passwd $USER
        fi
        if [ $? -ne 0 ]; then
          echo && echo "*** NB: TRY AGAIN #2: setting passwd for $USER" >&2
          $SUDO passwd $USER
          [ $? -ne 0 ] && exit 99
        fi
      else
        echo "*** password already set for: $USER"
      fi
    else
      echo "*** adding user: $USER"
      $SUDO useradd -m $USER

      echo "*** setting passwd for $USER"
      $SUDO passwd $USER

      if [ $? -ne 0 ]; then
        echo && echo "*** NB: TRY AGAIN #1: setting passwd for $USER" >&2
        $SUDO passwd $USER
      fi
      if [ $? -ne 0 ]; then
        echo && echo "*** NB: TRY AGAIN #2: setting passwd for $USER" >&2
        $SUDO passwd $USER
        [ $? -ne 0 ] && exit 99
      fi
    fi

    # set shell
    ZSH=$(chsh -l 2>/dev/null | grep zsh | tail -1)
    [ -z "$ZSH" ] && ZSH=$(which zsh 2>/dev/null)
    [ "$ZSH" = "/usr/bin/zsh" -a -x "/bin/zsh" ] && ZSH="/bin/zsh"

    # only change the user's shell to ZSH:
    # - if ZSH is installed
    # - we can find the .zshrc to give them
    if [ -x /bin/zsh -o -x /ur/bin/zsh ]; then
      ZSHRC="./Config-Files/.zshrc"
      [ ! -r $ZSHRC -a -r "./src/Config-Files/.zshrc" ] && ZSHRC="./src/Config-Files/.zshrc"
      [ ! -r $ZSHRC -a -r "./playground/Config-Files/.zshrc" ] && ZSHRC="./playground/Config-Files/.zshrc"
      [ ! -r $ZSHRC -a -r "~/src/Config-Files/.zshrc" ] && ZSHRC="~/src/Config-Files/.zshrc"
      [ ! -r $ZSHRC -a -r "~/playground/Config-Files/.zshrc" ] && ZSHRC="~/playground/Config-Files/.zshrc"
      CONFIG_BASE=$(dirname $ZSHRC)

      if [ ! -d /home/$USER ]; then
        echo "--FATAL: /home/$USER doesn't exist?!" >&2
        exit 99
      fi
      $SUDO cp -vpf "$ZSHRC" /home/$USER || exit 1
      $SUDO chown -v $USER /home/$USER/.zshrc || exit 1

      # check if user's ZSHRC exists
      ZSHRC_OK=$($SUDO ls /home/$USER/.zshrc 2>/dev/null)

      if [ -n "$ZSHRC_OK" ]; then
        if egrep -q "$USER:.*zsh" /etc/passwd; then
          echo "*** user << $USER >> arlaedy has ZSH as shell"
        else
          # is chsh available? (not available on Amazon Linux)
          if ! which chsh >&/dev/null; then
            echo "**** \`chsh' is not available on this system ... trying to install" 1>&2
            check_root
            OS=$(awk -F= '/^NAME=/{print $NF}' /etc/os-release)

            # various Linux -> installs csh
            if echo "$OS" | egrep -q "Amazon Linux|Fedora|CentOS|RHEL|Rocky"; then
              $SUDO yum -y install util-linux-user
            elif [ -x /usr/bin/yum ]; then
              $SUDO yum -y -qq install util-linux-user
            fi
          fi

          if which chsh >&/dev/null; then
            echo "*** setting \`$ZSH' as shell for user $USER"
            $SUDO chsh -s $ZSH $USER
            sleep 1
          else
            echo "*** no ChSH on this system!" >&2
          fi
        fi
      else
        echo "--WARN: no-USER-ZSHRC: were not able to change shell for user $USER to ZSH, run:"
        echo "$ $0 -ZSH"
      fi
    else
      echo "--WARN: no-ZSH-INSTALLED: were not able to change shell for user $USER to ZSH, run:"
      echo "$ $0 -ZSH"
    fi

    # set up some basics, such as ssh authorized keys
    if [ -n "$CONFIG_BASE" ]; then
      echo "- setting up $USER .ssh & homedir"
      U_HOME=/home/$USER

      $SUDO mkdir $U_HOME/.ssh
      $SUDO chmod -v 700 $U_HOME/.ssh
      $SUDO chown -v $USER $U_HOME/.ssh

      echo "- copying up << $CONFIG_BASE/.ssh/authorized_keys >> to $USER .ssh & homedir"
      [ -s $HOME/.ssh/authorized_keys ] && $SUDO cp -fv $HOME/.ssh/authorized_keys $U_HOME/.ssh/authorized_keys
      [ -s $CONFIG_BASE/.ssh/authorized_keys ] && $SUDO cp -fv $CONFIG_BASE/.ssh/authorized_keys $U_HOME/.ssh/authorized_keys
      $SUDO chmod 600 $U_HOME/.ssh/authorized_keys && $SUDO chown -v $USER $U_HOME/.ssh/authorized_keys
      $SUDO ls -lh $U_HOME/.ssh/authorized_keys
      $SUDO cat $U_HOME/.ssh/authorized_keys
      sleep 1
    else
      echo "--WARN: skip setting up $USER ssh and homedir..."
    fi

    # SUDOERS
    echo && echo -e "*** Would you like to add user \"$USER\" to sudoers? [y/N] \c"
    read CONF
    if [ "$CONF" = "y" -o "$CONF" = "Y" ]; then
      if grep -q "^sudo" /etc/group; then
        echo "- adding $USER to sudo group to allow sudo"
        $SUDO usermod -aG sudo $USER
        sleep 1
      elif grep -q "^wheel" /etc/group; then
        echo "- adding $USER to wheel group to allow sudo"
        $SUDO usermod -aG wheel $USER
        sleep 1
      else
        echo "--WARN: no group sudo to add $USER to..."
      fi
    fi

    # BONUS: copy the bkup-script
    BONUS_CONFIG_FILE="$(dirname $CONFIG_BASE)/bkup-and-transfer.sh"
    if [ -r "$BONUS_CONFIG_FILE" ]; then
      echo && echo "*** copying bonus config file \"$BONUS_CONFIG_FILE\" to $U_HOME"
      $SUDO cp -pv "$BONUS_CONFIG_FILE" "$U_HOME" || exit 1
      $SUDO chown -v $USER "$U_HOME/$(basename $BONUS_CONFIG_FILE)" || exit 1
      BONUS_FILE_COPIED="yes"
    fi

    # FINAL Instructions
    echo && echo "*** su to & setup the user: $USER"
    if [ -n "$BONUS_FILE_COPIED" ]; then
      echo "- eg: run: ./$(basename $BONUS_CONFIG_FILE)"
    else
      echo "- eg: run: <<  wget http://<<XXX>>.com/dl.sh && bash dl.sh >>"
    fi
    echo
    echo "+ $SUDO su - $USER"
    exec $SUDO su - $USER
    exit $?
  else
    echo "--FATAL: need to supply a user's name to create!" >&2
    exit 99
  fi
}

function ssh_conf() {
  setup
  check_root

  echo && echo "* [$(date +%H:%M)] current SSHD_CONFIG:"
  echo "- ACTIVE settings:"
  egrep '^#?(Port|PermitRootLogin|PubkeyAuthentication|PermitEmptyPasswords|PasswordAuthentication|AllowUsers)' /etc/ssh/sshd_config | grep -v '^#'
  echo "- COMMENTED OUT:"
  egrep '^#?(Port |PermitRootLogin|PubkeyAuthentication|PermitEmptyPasswords|PasswordAuthentication|AllowUsers)' /etc/ssh/sshd_config | grep '^#'
  sleep 1

  # To directly modify sshd_config.
  echo && echo "* [$(date +%H:%M)] modifying SSHD_CONFIG:"
  echo sed -i 's/#\?\(Port\s*\).*$/\1 2231/' /etc/ssh/sshd_config
  echo sed -i 's/#\?\(PermitRootLogin\s*\).*$/\1 no/' /etc/ssh/sshd_config
  echo sed -i 's/#\?\(PubkeyAuthentication\s*\).*$/\1 yes/' /etc/ssh/sshd_config
  echo sed -i 's/#\?\(PermitEmptyPasswords\s*\).*$/\1 no/' /etc/ssh/sshd_config
  echo sed -i 's/#\?\(PasswordAuthentication\s*\).*$/\1 no/' /etc/ssh/sshd_config

  # install fail2ban - to increase SSH security
  echo && echo "* [$(date +%H:%M)] install+setup: fail2ban"
  $SUDO apt-get install -qq -y fail2ban
  $SUDO systemctl enable fail2ban
  $SUDO systemctl start fail2ban

  # restart SSH
  $SUDO /etc/init.d/ssh restart
  #$SUDO service sshd restart
  #$SUDO service sshd reload
  #$SUDO systemctl stop ssh.service
  #$SUDO systemctl start ssh.service
}

function change_hostname() {
  setup
  check_root

  echo && echo "* [$(date +%H:%M)] setting a hostname to something non-default"

  # default
  HOSTNAME=localhost
  OS_NAME=$(awk -F= '/^ID=/{print $2}' /etc/os-release | sed 's/"//g')
  OS_RELEASE=$(grep "VERSION_ID=" /etc/os-release | sed 's/.*="\([0-9]*\).*/\1/; s/"//g')
  [ -n "$OS_NAME" ] && HOSTNAME=$OS_NAME
  [ -n "$OS_RELEASE" ] && HOSTNAME="$HOSTNAME$OS_RELEASE"

  # is this LINODE?
  [ -n "$LINODE_DATACENTERID" -a "$LINODE_DATACENTERID" = 6 ] && HOSTNAME="nj-$HOSTNAME"
  [ -n "$LINODE_DATACENTERID" -a "$LINODE_DATACENTERID" = 15 ] && HOSTNAME="tor-$HOSTNAME"

  # is this AWS EC2?
  if [ "$USER" = "ec2-user" ]; then
    AWS=1
    HOSTNAME="ec2-$HOSTNAME"
  elif echo "$(uname -n)" | grep -q "^ip-[0-9][0-9-]*[0-9]$"; then
    AWS=1
    HOSTNAME="ec2-$HOSTNAME"
  elif echo "$(uname -r)" | egrep -q ".(-aws|-amazon)$"; then
    AWS=1
    HOSTNAME="ec2-$HOSTNAME"
  fi

  # is this GCP?
  if echo "$(uname -r)" | egrep -q ".(-gcp|-google)$"; then
    GCP=1
    HOSTNAME="gcp-$HOSTNAME"
  fi

  # is this AZURE?
  if echo "$(uname -r)" | egrep -q ".(-azure)$"; then
    AZURE=1
    HOSTNAME="az-$HOSTNAME"
  fi

  # auto-change: did we get something?
  if [ "$1" ]; then
    echo "- setting hostname to: << $1 >> - auto-worked out hostname is $HOSTNAME"
    HOSTNAME=$1
  elif [ "$HOSTNAME" != "localhost" ]; then
    echo "- setting hostname to: << $HOSTNAME >>"
  fi

  #
  # EXEC
  #
  if [ "$HOSTNAME" != "localhost" -o -n "$1" ]; then
    OLD_HOSTNAME=$(hostname)

    $SUDO hostnamectl set-hostname --static $HOSTNAME
    RC=$?

    # update /etc/hosts
    if [ "$RC" -eq 0 ]; then
      echo && echo "* [$(date +%H:%M)] updating /etc/hosts with $HOSTNAME"

      if [ -n "$OLD_HOSTNAME" -a "$OLD_HOSTNAME" != "$HOSTNAME" ]; then
        $SUDO sed -i "s/^127.0.0.1\( *\)localhost $OLD_HOSTNAME$/127.0.0.1\1localhost $HOSTNAME/" /etc/hosts
        $SUDO sed -i "s/^127.0.0.1\( *\)localhost.localdomain localhost4 localhost4.localdomain4 $OLD_HOSTNAME$/127.0.0.1\1localhost.localdomain localhost4 localhost4.localdomain4 $HOSTNAME/" /etc/hosts
      fi

      $SUDO sed -i "s/^127.0.0.1\( *\)localhost$/127.0.0.1\1localhost $HOSTNAME/" /etc/hosts
      $SUDO sed -i "s/^127.0.0.1\( *\)localhost.localdomain localhost4 localhost4.localdomain4$/127.0.0.1\1localhost.localdomain localhost4 localhost4.localdomain4 $HOSTNAME/" /etc/hosts

      cat /etc/hosts
    else
      echo "--FATAL: ERROR RC=$RC running: $SUDO hostnamectl set-hostname --static $HOSTNAME" >&2
      exit 99
    fi
  fi

  # cloud hosts have a preserve_hostname setting
  if [ -s /etc/cloud/cloud.cfg -o -n "$AWS" -o -n "$GCP" ]; then
    echo && echo "***NB****: note that on Public Cloud hosts need to change /etc/cloud/cloud.cfg to preserve_hostname across reboots:"
    grep -i preserve_hostname /etc/cloud/cloud.cfg
    sleep 1
  fi

  # recommended: perform apt update
  echo && echo "* [$(date +%H:%M)] /OPTIONAL/ perform apt update/upgrade on $HOSTNAME, hit Ctrl-C to cancel"
  if which apt >&/dev/null; then
    $SUDO nice apt update -qq && $SUDO nice apt upgrade -yq
  fi

  # reload the shell
  # - this is needed to reflect the new prompt
  exec $SHELL --login
}

#
# MAIN
#

####################
PROG=$(basename $0)
if [ $# -eq 0 -o "$1" = "-h" -o "$1" = "--help" ]; then
  cat <<! >&2
$PROG: Script to setup a new Linux system, eg: install packages via \`yum/apt'
       * install the most important PKGs, for convenience, dev, etc

Usage: $PROG <options> [param]
        -TZ     set the system's timezone (apt-based systems)
        -GENPKG general install apt/yum pkgs: on Linux (Ubuntu, Mint, Debian etc) [apt/yum]
        -ZSH    enable the \`zsh' shell via \`chsh'

        -USER <user> add/create a user (run as root) [interactive]

        -SSH1   install/enable SSH server via apt (for SSH-ing in) * useful on Mint Linux
        -SSH0   disable & completely remove SSH server (via apt)

        -BREW   install brew pkgs: MacOS/Darwin (uses brew)
        -RH     install yum  pkgs: RHEL Red Hat Linux (uses yum)
        -PI     install apt  pkgs: Raspbian PI Linux (uses apt)

        -SSH_CONF         sets-up SSHD & fail2ban (useful when SSH on public Internet)
                          * also confirms current SSHD config
        -HOSTNAME [name]  change hostname to something more meaningful
                          * optional param with the new hostname

        -h      this screen
!
elif [ "$1" = "-GENPKG" ]; then
  install_general_packages
elif [ "$1" = "-TZ" ]; then
  change_timezone
elif [ "$1" = "-ZSH" ]; then
  enable_setup_zsh
elif [ "$1" = "-USER" ]; then
  create_user $2
elif [ "$1" = "-SSH1" ]; then
  enable_ssh
elif [ "$1" = "-SSH0" ]; then
  disable_ssh
elif [ "$1" = "-BREW" ]; then
  install_brew
elif [ "$1" = "-SSH_CONF" -o "$1" = "-sshconf" ]; then
  ssh_conf
elif [ "$1" = "-HOSTNAME" -o "$1" = "-hostname" ]; then
  change_hostname $2
elif [ "$1" = "-PI" ]; then
  install_pi
elif [ "$1" = "-RH" ]; then
  install_rhel
else
  echo "$PROG: see usage via \`$PROG --help' ..." 2>&1
  exit 1
fi

# EOF
