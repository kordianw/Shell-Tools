#!/bin/bash
#
# Script to setup a Linux system, eg: install additional packages on a Linux machine
# - works on RHEL, Ubuntu, Debian (incl. Mint) and Raspbian
#
# * By Kordian Witek <code [at] kordy.com>, Nov 2017
#

#
# FUNCTIONS
#
function setup()
{
  # what is the package manager to choose?
  if [ -x /usr/bin/apt -a -x /usr/bin/yum ]; then
    echo "$PROG: both \`apt' and \`get' are installed! can't choose the package manager!" >&2; exit 99
  elif [ -x /usr/bin/apt ]; then
    PKG=apt
  elif [ -x /usr/bin/yum ]; then
    PKG=yum
  else
    echo "$PROG: neither \`apt' and \`get' are installed! can't choose the package manager!" >&2; exit 99
  fi

  # do we need sudo?
  SUDO="sudo"

  # where is my SRC dir located?
  KW_SRC_DIR="$HOME/src"
  [ -d "$HOME/playground" ] && KW_SRC_DIR="$HOME/playground"
}

function install_general_packages
{
  #
  # TODO Mint Linux
  #
  # - boot Lenovo ThinkPad T480s from USB via "Enter,F12"
  # - change timezone (Start: Clock)
  # - add percentage to battery panel (right click, properties)
  # - reverse the scroll direction (Start,Mouse/TouchPad)
  # - connect WIFI & Disable Bluetooth
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
  #   * install SSH via this script (CAREFFUL)
  # - LOGIN REMOTELY via ssh: ssh t480s
  #   * copy Config files
  # - chsh
  #   /bin/zsh
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

  [ "$OSTYPE" != "linux-gnu" ] && { echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnu >>!" >&2; exit 2; }
  [ ! -r /etc/os-release ] && { echo "$PROG: no /etc/os-release file, is this really Linux ?" >&2; exit 3; }

  # setup program & vars
  setup

  # -y=yes, -q=quiet
  if [ "$PKG" = "apt" ]; then
    INSTALL_CMD="$SUDO apt install -qq -y"
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
  echo && echo "* installing packages..."

  # major packages - CLI & GUI
  $INSTALL_CMD vim           # VIM: improved vi (VI iMproved)
  $INSTALL_CMD zsh           # the Z Shell (more powerful than bash)
  #$INSTALL_CMD chromium-browser
  #$INSTALL_CMD vlc
  #$INSTALL_CMD remmina
  #$INSTALL_CMD remmina-plugin-rdp
  #$INSTALL_CMD remmina-plugin-vnc

  # Laptop specific tools (can comment out)
  #$INSTALL_CMD acpi          # view battery/ACPI information (LAPTOPS)
  #$INSTALL_CMD acpitool      # view battery/ACPI information (LAPTOPS)
  #$INSTALL_CMD wavemon       # wireless Device Monitoring Application (LAPTOPS)
  #$INSTALL_CMD powertop      # diagnose issues with power consumption and management (LAPTOPS)
  #$INSTALL_CMD cpufrequtils  # utilities to deal with the cpufreq Linux kernel feature
  #$INSTALL_CMD caffeine      # prevent the desktop becoming idle in full-screen mode

  # terminal multipliers
  $INSTALL_CMD screen        # GNU screen
  $INSTALL_CMD tmux          # GNU tmux

  # text-based browsers
  $INSTALL_CMD lynx          # classic non-graphical (text-mode) web browser
  $INSTALL_CMD links         # Web browser running in text mode
  $INSTALL_CMD w3m           # WWW browsable pager with excellent tables/frames support

  # development
  $INSTALL_CMD git           # github/git
  
  # compiling / gcc
  $INSTALL_CMD build-essential
  $INSTALL_CMD gcc           # GNU compiler
  $INSTALL_CMD libc6-dev     # LIBC dev headers
  $INSTALL_CMD automake      # automake
  $INSTALL_CMD openssl       # SSL
  $INSTALL_CMD libssl-dev    # SSL libraries
  $INSTALL_CMD libncurses5-dev libncursesw5-dev

  # additional modules
  $INSTALL_CMD libjson-perl        # JSON.pm
  $INSTALL_CMD libdate-manip-perl  # DateManip.pm

  # system utils (may require cron-entries)
  #$INSTALL_CMD sysstat       # install stat utils such as sar, iostat, etc
  #$INSTALL_CMD mlocate       # quickly find files on the filesystem based on their name
  [ -x /usr/bin/apt ] && $INSTALL_CMD apt-file      # search for files within Debian packages (CLI)

  # system utils (do not require cron)
  $INSTALL_CMD inxi          # full featured system information script
  $INSTALL_CMD lshw          # information about hardware configuration, incl. lspci
  $INSTALL_CMD hwinfo        # Hardware identification system
  $INSTALL_CMD dmidecode     # active/passive network address scanner using ARP requests
  $INSTALL_CMD hdparm        # tune hard disk parameters for high performance
  $INSTALL_CMD sysbench      # multi-threaded benchmark tool
  $INSTALL_CMD lsof          # Utility to list open files
  $INSTALL_CMD ncdu          # Disk usage analysis

  # network & security tools
  $INSTALL_CMD telnet        # telnet for checking connectivity
  $INSTALL_CMD dnsutils      # provides dig+nslookup
  $INSTALL_CMD netcat        # TCP/IP swiss army knife
  $INSTALL_CMD nmap          # The Network Mapper/Scanner
  $INSTALL_CMD netdiscover   # SMBIOS/DMI table decoder
  $INSTALL_CMD ntpdate       # one-off synchronize clock with a remote NTP server
  $INSTALL_CMD ntpstat       # show network time protocol (ntp) status
  $INSTALL_CMD ethtool       # display or change Ethernet device settings
  $INSTALL_CMD aircrack-ng   # wireless WEP/WPA cracking utilities
  $INSTALL_CMD sshpass       # Non-interactive ssh password authentication

  # small utils (just helper utils)
  $INSTALL_CMD tofrodos      # unix2dos, dos2unix
  $INSTALL_CMD bc            # CLI calculator
  $INSTALL_CMD par           # advanced Paragraph reformatter (can be used inside vim)
  $INSTALL_CMD pydf          # colourised df(1)-clone
  $INSTALL_CMD htop          # improved `top'

  if [ "$PKG" = "apt" ]; then
    # update the apt-file utility
    echo && echo "* updating the apt-file cache..."
    $SUDO apt-file update

    # store a backup of currently installed packages
    echo && echo "* storing a backup of all installed packages..."
    DIR=`dirname "$0"`
    dpkg -l > $DIR/pkg-installed-list.txt
  fi

  # ==== Useful APT commands:
  # LIST & SEARCH:
  # - dpkg -l                     List all installed packages
  # - apt search search_string    Search for packages
  # - apt show package            Show locally-cached details about package (local+remote)
  # - apt list                    List all AVAILABLE packages (to be installed)
  # - apt list --upgradable       List all packages that are installed and which can be upgraded
  # - apt changelog package       Shows changelogs for packages (v.useful)
  # - apt-cache showpkg package   Shows package dependencies (reverse & forward)
  #
  # QUERY:
  # - dpkg -s package             Show info only locally installed package (cf: rpm -qi)
  # - dpkg -L package             List files installed by a package (cf: rpm -ql)
  # - dpkg -S /path/file          List which package a given file belongs to (cf: rpm -qf)
  #
  # INSTALL:
  # - sudo apt install package    Download & install/upgrade (resolving dependencies)
  #                               * apt install --only-upgrade package <-- only upgrades
  # - sudo dpkg -i package        install local pkg
  #
  # REMOVE:
  # - sudo apt remove package     Uninstalls a package
  # - sudo apt purge package      Uninstalls a package + removes any config files
  # - sudo apt autoremove         Removes unneeded packages (eg: installed as prior dependencies)
  #
  # UPGRADE:
  # - apt list --upgradable       List all packages that are installed and which can be upgraded
  # - apt policy package          Shows all available versions of package that can be installed
  # - apt changelog package       Shows changelogs for packages (v.useful)
  # - sudo apt update             Update the local database to make sure it matches remote sources
  # - sudo apt upgrade            Only upgrades installed packages, where possible (no removal).
  # - sudo apt safe-upgrade       Same, but installed packages will not be removed unless they are unused.
  # - sudo apt dist-upgrade       Same, but may add or remove packages to satisfy new dependencies.
  #                               * apt-get -s dist-upgrade <-- simulation to see what it would do
  #
  # CLEAN:
  # - sudo apt-get clean          Free up the disk space by cleaning retrieved .deb packages
  # - sudo apt-get autoclean      Deletes all .deb files from /var/cache/apt/archives to free-up disk space
  # - sudo apt autoremove         Removes unneeded packages (eg: installed as prior dependencies)
  #
  # APT_FILE:
  # - sudo apt-file update        Update the apt-file database locally
  # - apt-file search /path/file  Search what package provides /path/file
  # - apt-file list package       Show files to be installed by a package
  # Note: apt is a front-end for apt-get, apt-cache and dpkg
  #
  # apt history is in /var/log/apt/history.log
}

function enable_zsh()
{
  # setup program & vars
  setup

  # check for ZSH
  ZSH=`chsh -l | grep zsh`

  # is ZSH available?
  if [ -z "$ZSH" ]; then
    echo -e "$PROG: The zsh SHELL is not available/installed: run\n# $PKG install zsh" >&2; exit 4
  fi

  # make sure we have ZSHRC installed
  if [ ! -r $HOME/.zshrc ]; then
    echo "$PROG: create a $HOME/.zshrc file before changing the shell!" >&2; exit 5
  fi

  #
  # EXEC
  #
  set -x
  $SUDO chsh -s $ZSH $USER
}

function enable_ssh()
{
  [ "$OSTYPE" != "linux-gnu" ] && { echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnu >>!" >&2; exit 2; }
  [ ! -r /etc/os-release ] && { echo "$PROG: no /etc/os-release file, is this really Linux ?" >&2; exit 3; }
  [ ! -x /usr/bin/apt ] && { echo "$PROG: can't find/exec APT!" >&2; exit 4; }

  # do we need to install it? maybe it's already installed...
  if [ -e /usr/sbin/sshd -a -e /etc/init.d/ssh ]; then
    echo "* SSHD already installed: not installing openssh-server"
  else
    echo "* installing: openssh-server"
    $SUDO apt install -qq -y openssh-server
  fi

  echo "* disabling: ssh from auto-restarting (OPTIONAL)"
  $SUDO systemctl disable ssh.service

  echo "* starting ssh service"
  $SUDO systemctl start ssh.service

  echo "* check-status: systemctl status ssh"
  $SUDO systemctl status ssh

  echo && echo "* NOTE: in Mint Linux, default user \`mint' has no password, therefore need to add to \`/etc/ssh/sshd_config':"
  echo "PermitEmptyPasswords yes"
  echo && echo "# sudo vi /etc/ssh/sshd_config"
  echo "# systemctl restart ssh.service"
}

function disable_ssh()
{
  [ "$OSTYPE" != "linux-gnu" ] && { echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnu >>!" >&2; exit 2; }
  [ ! -r /etc/os-release ] && { echo "$PROG: no /etc/os-release file, is this really Linux ?" >&2; exit 3; }
  [ ! -x /usr/bin/apt ] && { echo "$PROG: can't find/exec APT!" >&2; exit 4; }

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

function install_pi()
{
  # RASPBIAN PI
  [ "$OSTYPE" != "linux-gnueabihf" ] && { echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnueabihf >>!" >&2; exit 2; }
  [ ! -r /etc/os-release ] && { echo "$PROG: no /etc/os-release file, is this really Linux ?" >&2; exit 3; }
  [ ! -x /usr/bin/apt ] && { echo "$PROG: can't find/exec APT!" >&2; exit 4; }

  # -y=yes, -q=quiet
  INSTALL_CMD="sudo apt install -qq -y"

  # update the local database to make sure it matches remote sources
  echo "* updating the apt local database..."
  sudo apt update

  # apps
  echo && echo "* installing packages..."

  # major packages
  $INSTALL_CMD vim           # VIM: improved vi (VI iMproved)
  $INSTALL_CMD zsh           # the Z Shell (more powerful than bash)

  # terminal multipliers
  $INSTALL_CMD screen        # GNU screen
  $INSTALL_CMD tmux          # GNU tmux

  # text-based browsers
  $INSTALL_CMD lynx          # classic non-graphical (text-mode) web browser
  $INSTALL_CMD links         # Web browser running in text mode
  $INSTALL_CMD w3m           # WWW browsable pager with excellent tables/frames support

  # development
  $INSTALL_CMD git           # github/git

  # additional modules
  $INSTALL_CMD libjson-perl  # JSON.pm

  # system utils (may require cron-entries)
  $INSTALL_CMD apt-file      # search for files within Debian packages (CLI)
  $INSTALL_CMD sysstat       # install stat utils such as sar, iostat, etc
  $INSTALL_CMD mlocate       # quickly find files on the filesystem based on their name

  # system utils (do not require cron)
  $INSTALL_CMD inxi          # full featured system information script
  $INSTALL_CMD lshw          # information about hardware configuration, incl. lspci
  $INSTALL_CMD hwinfo        # Hardware identification system
  $INSTALL_CMD dmidecode     # active/passive network address scanner using ARP requests
  $INSTALL_CMD hdparm        # tune hard disk parameters for high performance
  $INSTALL_CMD sysbench      # multi-threaded benchmark tool
  $INSTALL_CMD lsof          # Utility to list open files
  $INSTALL_CMD ncdu          # Disk usage analysis

  # network & security tools
  $INSTALL_CMD telnet        # telnet for checking connectivity
  $INSTALL_CMD dnsutils      # provides dig+nslookup
  $INSTALL_CMD netcat        # TCP/IP swiss army knife
  $INSTALL_CMD nmap          # The Network Mapper/Scanner
  $INSTALL_CMD netdiscover   # SMBIOS/DMI table decoder
  $INSTALL_CMD ntpdate       # one-off synchronize clock with a remote NTP server
  $INSTALL_CMD ntpstat       # show network time protocol (ntp) status
  $INSTALL_CMD ethtool       # display or change Ethernet device settings
  $INSTALL_CMD aircrack-ng   # wireless WEP/WPA cracking utilities
  $INSTALL_CMD sshpass       # Non-interactive ssh password authentication

  # small utils (just helper utils)
  $INSTALL_CMD tofrodos      # unix2dos, dos2unix
  $INSTALL_CMD bc            # CLI calculator
  $INSTALL_CMD par           # advanced Paragraph reformatter (can be used inside vim)
  $INSTALL_CMD pydf          # colourised df(1)-clone
  $INSTALL_CMD htop          # improved `top'

  # update the apt-file utility
  echo && echo "* updating the apt-file cache..."
  $SUDO apt-file update

  # store a backup of currently installed packages
  echo && echo "* storing a backup of all installed packages..."
  DIR=`dirname "$0"`
  dpkg -l > $DIR/pkg-installed-list.txt
}

function install_rhel()
{
  # RED HAT LINUX

  [ "$OSTYPE" != "linux-gnu" ] && { echo "$PROG: invalid arch << $OSTYPE >>, expecting << linux-gnu >>!" >&2; exit 2; }
  [ ! -r /etc/redhat-release ] && { echo "$PROG: no /etc/redhat-release file, is this really RHEL ?" >&2; exit 3; }
  [ ! -x /usr/bin/yum ] && { echo "$PROG: can't find/exec YUM, eg for: yum install!" >&2; exit 4; }

  # MAJOR packages
  sudo yum -y install ansible                # Ansible
  sudo yum -y install s3cmd.noarch           # S3CMD - S3 CLI

  # TERMINAL
  sudo yum -y install screen                 # GNU screen
  sudo yum -y install tmux                   # TMUX

  # WBE BROWSING
  sudo yum -y install links                  # text-based web-browser #1
  sudo yum -y install lynx                   # text-based web-browser #2

  # MAIL
  sudo yum -y install mutt                   # allow better command line mail
  sudo yum -y install mailx                  # send cmd line mail

  # DEVEL
  sudo yum -y install vim                    # editor of choice
  sudo yum -y install perl
  sudo yum -y install python
  sudo yum -y install git                    # GIT/GITHUB access
  sudo yum -y install strace                 # debug running processes

  # COMPILING
  sudo yum -y install gcc                    # GNU compiler
  sudo yum -y install automake               # automake
  sudo yum -y install openssl                # SSL
  sudo yum -y install openssl-devel          # SSL libraries

  # SHELLS
  sudo yum -y install zsh                    # Z-Shell: my favourite shell
  sudo yum -y install tcsh                   # allow CSH for copy/paste purposes

  # UTILS
  sudo yum -y install nfs-utils              # NFS mount, showmount, etc
  sudo yum -y install wget
  sudo yum -y install curl
  sudo yum -y install zip                    # installs ZIP support
  sudo yum -y install unzip                  # installs ZIP support (unzip)
  sudo yum -y install bzip2                  # installs bzip2 support
  sudo yum -y install rsync                  # GNU rsync
  sudo yum -y install tofrodos               # installs unix2dos/dos2unix
  sudo yum -y install bind-utils             # nslookup/host/git
  sudo yum -y install telnet
  sudo yum -y install nc                     # ncat/netcat
  sudo yum -y install bc                     # calculator
  sudo yum -y install sharutils              # uuencode/uudecode
  sudo yum -y install finger                 # allow: finger username
  sudo yum -y install words                  # database of common English words
  sudo yum -y install sshpass                # non-interactive SSH
  sudo yum -y install mlocate                # locate DB (fast `find')
  sudo yum -y install lshw                   # HW list + monitor
  sudo yum -y install hwinfo                 # HW list + monitor
  sudo yum -y install inxi                   # HW list + monitor

  # get the EPEL repository
  sudo yum -y install epel-release
  #wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-10.noarch.rpm
  #sudo rpm -ihv epel-release-7-10.noarch.rpm

  sudo yum -y install htop                   # better version of `top'
  sudo yum -y install sysbench               # basic system benchmark

  # PERL: additional Perl modules (if working with Perl a lot)
  sudo yum -y install perl-LWP-UserAgent-Determined

  sudo yum -y install perl-XML-Simple        # for XML parsing
  sudo yum -y install perl-JSON              # for JSON parsing

  sudo yum -y install perl-DBI
  sudo yum -y install perl-DBD-MySQL

  # PERL: optional: other misc modules (these can be installed locally)
  sudo yum -y install perl-Data-Dumper
  sudo yum -y install perl-Mail-Sender
  sudo yum -y install perl-DateTime
  sudo yum -y install perl-Date-Calc
  sudo yum -y install perl-Mozilla-CA        # for SSL handling
}

#
# MAIN
#

####################
PROG=`basename $0`
if [ $# -eq 0 -o "$1" = "-h" ]; then
  cat <<! >&2
$PROG: Script to setup a new Linux system, eg: install packages via \`yum/apt'
       * install the most important PKGs, for convenience, dev, etc

Usage: $PROG <options> [param]
        -GENPKG general install apt/ym pkgs: on Linux (Ubuntu, Mint, Debian etc) [apt/yum]
        -ZSH    enable the \`zsh' shell via \`chsh'

        -SSH1   install/enable SSH server via apt (for SSH-ing in) * useful on Mint Linux
        -SSH0   disable & completely remove SSH server (via apt)

        -RH     install yum pkgs: RHEL Red Hat Linux (uses yum)
        -PI     install apt pkgs: Raspbian PI Linux (uses apt)

        -h      this screen
!
elif [ "$1" = "-GENPKG" ]; then
  install_general_packages;

elif [ "$1" = "-ZSH" ]; then
  enable_zsh;

elif [ "$1" = "-SSH1" ]; then
  enable_ssh;

elif [ "$1" = "-SSH0" ]; then
  disable_ssh;

elif [ "$1" = "-PI" ]; then
  install_pi;

elif [ "$1" = "-RH" ]; then
  install_rhel;

else

  echo "$PROG: see usage via \`$PROG --help' ..." 2>&1
  exit 1
fi

# EOF
