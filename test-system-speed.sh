#!/bin/bash
# tests CPU+Mem+IO speed using `CPUmark' or `sysbench'
# - in sysbench mode, writes test files to current dir, testing disk
#
# NB: for CPU Mark, more extensive testing:
# wget https://www.passmark.com/downloads/pt_linux_x64.zip
# wget https://www.passmark.com/downloads/pt_linux_x86_64_legacy.zip
#
# MODES:
# -cpumark <-- CPU MARK MODE: tries to download and use CPU Mark tests (best option)
# -sysbench<-- SYSBENCH MODE: uses sysbench
# -ssd     <-- SSD MODE: crude way to work out if current disk is SSD or not
#
# OPTIONS:
# -cpumark <-- tries to download and use CPU Mark tests (best option)
# -install <-- tries to install `sysbench' if not installed
# -cpu     <-- just the sysbench CPU testing
# -memory  <-- sysbench memory testing included
# -hdparm  <-- adds a hdparm test at the end
#
# * By Kordian W. <code [at] kordy.com>, Jan 2020
#

# maximum number prime to calculate - this usually takes around 1-2mins so is a perfect test
MAX_PRIME=20000

# what is the file size we test IO with?
SIZE_TO_TEST="2G"
SIZE_TO_TEST_COUNT="2048"

# what is the minimum disk space we require in MB?
MIN_SPACE_NEEDED=2500

##################
PROG=$(basename $0)
if [ ! -w . ]; then
  echo "$PROG: you don't have permission to test in the current dir!" >&2
  exit 1
fi

# CHOOSE MODE
if [ $# -eq 0 ]; then
  echo "$PROG: please choose the MODE:" >&2
  echo " -cpumark  <- CPU MARK MODE: tries to download and use CPU Mark tests (best option)" >&2
  echo " -sysbench <- SYSBENCH MODE: uses sysbench" >&2
  echo " -ssd      <- SSD? MODE: crude way to work out if current disk is SSD or not" >&2
  echo >&2
  echo "... once sysbench is installed (via -install), use: -cpu, or -mem to start the test" >&2
  exit 1
fi

#
# CPUMARK
# - check SSD/HDD speed - crude way ...
#
if [ "$1" = "-ssd" -o "$1" = "--ssd" ]; then
  echo "$PROG: trying to execute MODE: \`ssd check' ..." >&2

  COUNT=2000

  # check if the root drive is SSD
  # - if SSD, cmd will take around 1 sec
  # - if HDD, cmd will take around 10 sec

  echo "* $PROG: timing $COUNT disk reads on your disks ..."
  echo "  - if it takes ~2 secs to read disk, most likely it's an SSD"
  echo "  - if it takes >5 secs to read disk, most likely it's an HDD"

  DF_CMD=$(df -lTh -x tmpfs -x devtmpfs -x squashfs -x fuse.sshfs | grep -E -v '/boot/efi')

  echo && echo "* df output:"
  echo "$DF_CMD"

  if ! command -v lsblk >&/dev/null; then
    echo "--FATAL: you don't have \`lsblk' installed!" >&2
    echo "run: apt-get install util-linux" >&2
    exit 99
  fi

  echo && echo "* lsblk output:"
  lsblk | grep "/" | grep -E -v 'loop|/boot/efi' | grep '[0-9]'
  lsblk -d -e 1,7 -o NAME,MAJ:MIN,TYPE,FSTYPE,SIZE,RO,VENDOR,MODEL,ROTA,MOUNTPOINT,GROUP,MODE | grep -E -v 'CD.ROM'

  # can we use sudo?
  if [ "$EUID" -ne 0 ]; then
    sudo -n whoami >&/dev/null
    if [ $? -eq 0 ]; then
      echo "* will use sudo to run tests to make results more accurate" >&2
      SUDO="sudo"
    else
      echo && echo "*** WARNING *** can't use sudo as current user, results may not be 100% accurate ..." >&2
      SUDO=""
    fi
  else
    SUDO=""
  fi

  ##########################################################

  if [ -n "$DF_CMD" ]; then
    for a in $(lsblk -d -e 1,7 -o NAME | grep -v NAME); do
      DEV="/dev/$a"
      echo && echo "**** DEV << $DEV >>"
      time for i in $(seq 1 $COUNT); do
        $SUDO dd bs=4k if=$DEV count=1 skip=$(($RANDOM * 128)) >/dev/null 2>&1
      done 2>&1 | grep real
      sleep 3
    done
  else
    echo "--FATAL: can't work out which dev to test on!" >&2
    exit 99
  fi

  ##########################################################

  exit 0

#
# CPUMARK
#
elif [ "$1" = "-cpumark" ]; then

  echo "$PROG: trying to execute MODE: \`cpumark' ..." >&2

  # quick install...
  if ! command -v unzip >&/dev/null; then
    if [ -x /usr/bin/apt ]; then
      echo "- trying to install dependencies via apt: unzip & libncurses"
      sudo apt update -qq
      sudo apt install -y -qq unzip libncurses5
    elif [ -x /usr/bin/yum ]; then
      echo "- trying to install dependencies via yum: unzip & libncurses"
      #dnf install unzip
      #dnf install ncurses-compat-libs
      sudo yum install -qq -y unzip
      sudo yum install -qq -y ncurses-libs
    fi
  fi

  if ! command -v unzip >&/dev/null; then
    echo "--FATAL: needs UNZIP to run ..." >&2
    exit 99
  fi

  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:.:./cpumark:~/bin/cpumark

  #
  # LINUX
  #
  if [ "$OSTYPE" = "linux-gnu" -o "$OSTYPE" = "linux" ]; then

    if [ -x ~/bin/cpumark/pt_linux_x64 ]; then
      echo "$PROG: found cpumark (modern) - running \`cpumark' ..." >&2
      ~/bin/cpumark/pt_linux_x64 -r 3
      RC=$?
    elif [ -x ~/bin/cpumark/pt_linux_x86_64_legacy ]; then
      echo "$PROG: found cpumark (legacy) - running \`cpumark' ..." >&2
      ~/bin/cpumark/pt_linux_x86_64_legacy
      RC=$?
    else
      # DOWNLOAD & INSTALL
      echo "$PROG: trying to download & install \`cpumark' ..." >&2
      wget https://www.passmark.com/downloads/pt_linux_x64.zip &&
        unzip pt_linux_x64.zip &&
        rm -f pt_linux_x64.zip &&
        mv ./PerformanceTest ~/bin/cpumark &&
        ~/bin/cpumark/pt_linux_x64 -r 3
      RC=$?
    fi

    if [ $RC -ne 0 -a -r /usr/lib/x86_64-linux-gnu/libncurses.so.6 ]; then
      echo "$PROG: #1: trying to copy required libraries for \`cpumark' ..." >&2
      cp -pv /usr/lib/x86_64-linux-gnu/libncurses.so.6 ~/bin/cpumark/libncurses.so.5
      ~/bin/cpumark/pt_linux_x64 -r 3
      RC=$?
    fi

    if [ $RC -ne 0 -a -r /usr/lib/libncurses.so.6 ]; then
      echo "$PROG: #2: trying to copy required libraries for \`cpumark' ..." >&2
      cp -pv /usr/lib/libncurses.so.6 ~/bin/cpumark/libncurses.so.5
      ~/bin/cpumark/pt_linux_x64 -r 3
      RC=$?
    fi

    if [ $RC -ne 0 -a -r /usr/lib64/libncurses.so.6 ]; then
      echo "$PROG: #2: trying to copy required libraries for \`cpumark' ..." >&2
      cp -pv /usr/lib64/libncurses.so.6 ~/bin/cpumark/libncurses.so.5
      ~/bin/cpumark/pt_linux_x64 -r 3
      RC=$?
    fi

    # fall-back ...
    if [ $RC -ne 0 ]; then
      echo && echo "--FAILURE ... fallback to legacy version!" >&2
      mkdir ~/bin/cpumark >&/dev/null

      if [ -x ~/bin/cpumark/pt_linux_x86_64_legacy ]; then
        echo "$PROG: trying to run \`cpumark legacy' ..." >&2
        ~/bin/cpumark/pt_linux_x86_64_legacy
      else
        echo "$PROG: trying to download & install \`cpumark legacy' ..." >&2
        cd ~/bin/cpumark >&/dev/null &&
          wget https://www.passmark.com/downloads/pt_linux_x86_64_legacy.zip &&
          unzip pt_linux_x86_64_legacy.zip &&
          rm -f pt_linux_x86_64_legacy.zip &&
          cd $HOME >&/dev/null &&
          ~/bin/cpumark/pt_linux_x86_64_legacy -r 3
      fi
      RC=$?
    fi

  #
  # MAC
  #
  else
    if [ -x ~/bin/cpumark/pt_mac ]; then
      echo "$PROG: found cpumark (mac) - running \`cpumark' ..." >&2
      ~/bin/cpumark/pt_mac -r 3
      RC=$?
    else
      # DOWNLOAD & INSTALL
      echo "$PROG: trying to download & install \`cpumark' ..." >&2
      #wget https://www.passmark.com/downloads/pt_mac.zip &&
      curl -k -o pt_mac.zip https://www.passmark.com/downloads/pt_mac.zip &&
        unzip pt_mac.zip &&
        rm -f pt_mac.zip &&
        mv ./PerformanceTest ~/bin/cpumark &&
        ~/bin/cpumark/pt_mac -r 3
      RC=$?
    fi
  fi

  #
  # RESULTS:
  #
  RESULTS=results_all.yml
  [ -r ~/results_all.yml ] && RESULTS=~/results_all.yml
  if [ -r $RESULTS ]; then
    echo "*** RESULTS:" >&2
    grep -E "SUMM|Process|Memory|SINGLETHREAD" $RESULTS
    mv -f $RESULTS ~/bin/cpumark
  fi

  exit $RC
fi

#
# SYSBENCH
#
if [ "$1" = "-install" ]; then
  if ! command -v sysbench >&/dev/null; then
    echo "$PROG: trying to install \`sysbench' ..." >&2

    # quick install...
    if [ -x /usr/bin/apt ]; then
      echo "- trying to install sysbench via apt:"
      sudo apt update -qq
      sudo apt install -y -qq sysbench
    else
      echo "- trying to download & build from source, see if we can install:"
      [ -x /usr/bin/yum ] && echo "  > yum install -y libtool"
      echo "  > ./autogen.sh"
      echo "  > ./configure --without-mysql"
      echo "  > ./make"
      echo "- binary should be in ./src, & copied to ~/bin"

      echo "Step 1 is to intall some packages via YUM INSTALL:"
      [ -x /usr/bin/yum ] && sudo yum install -qq -y libtool pkgconfig
      [ -x /usr/bin/yum ] && sudo yum install -qq -y pkgconfig
      [ -x /usr/bin/yum ] && sudo yum install -qq -y make

      echo "Step 2 is to download & build:"
      set -x
      curl -sSL -o sysbench-1.0.20.tar.gz https://github.com/akopytov/sysbench/archive/refs/tags/1.0.20.tar.gz &&
        tar xzf sysbench-1.0.20.tar.gz &&
        rm -fv sysbench-1.0.20.tar.gz &&
        cd sysbench-1.0.20 &&
        ./autogen.sh &&
        ./configure --without-mysql &&
        make &&
        mv -v src/sysbench ~/bin
      set +x
    fi
  else
    echo "$PROG: sysbench seems already installed:"
    which sysbench
  fi
fi

# do we now have it?
if ! command -v sysbench >&/dev/null; then
  echo "$PROG: --FATAL: you don't have \`sysbench' installed; can't do any CPU performance testing, you can install:" >&2
  RUN=$0
  RUN=$(sed "s|$HOME|~|" <<<$0 2>/dev/null)
  echo -e "----> TRY:\n$ $RUN -install"
  exit 2
fi

# load any other LD library paths
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(dirname $(which sysbench))

# allow working with less capacity
if [ "$1" = "-1GB" ]; then
  shift

  MIN_SPACE_NEEDED=1100
  SIZE_TO_TEST="1G"
  SIZE_TO_TEST_COUNT="1024"
fi

# check for space
if [ "$1" = "-cpu" -o "$1" = "-CPU" -o "$1" = "--cpu" ]; then
  echo "$PROG: just CPU testing..."
  SPACE_LEFT=
else
  SPACE_LEFT=$(df -m . | awk '/^\/|^overlay/{print $4}')
  if [ -z "$SPACE_LEFT" ]; then
    echo "$PROG: can't calculate space left in current dir - via: \`df -m .'" >&2
    echo "--WARN: skipping HD tests"
  elif [ $SPACE_LEFT -lt $MIN_SPACE_NEEDED ]; then
    echo -e "$PROG: FATAL: not enough space left in current dir - seeing $SPACE_LEFT MB, needs at least $MIN_SPACE_NEEDED MB - see below:" >&2
    df -h .
    echo -e "\nNOTE: can use \"-1GB\" param to reduce the requirements..." >&2
    exit 99
  fi
fi

##################

# show HW information if available
if command -v hw-info.sh >&/dev/null; then
  hw-info.sh
elif [ -x ~/src/HW-Info/hw-info.sh ]; then
  ~/src/HW-Info/hw-info.sh
fi

# sysbench: old-style of new style?
SYSBENCH_TEST=""
THREADS_PARAM=""
if $(sysbench --version | grep -q "sysbench 0\."); then
  SYSBENCH_TEST="--test="
  THREADS_PARAM="num-"
fi

# set hostname
HOST=$(hostname 2>/dev/null)
[ -z "$HOST" ] && HOST=$(uname -n)

#
# CPU TEST
#
if [ "$1" = "-cpu" -o "$1" = "-CPU" -o "$1" = "--cpu" -o -z "$1" ]; then
  # work out how many CPUs (threads) we have?
  THREADS=$(lscpu 2>/dev/null | awk '/^CPU\(s\):/{print $NF}')
  if [ -z "$THREADS" ]; then
    THREADS=$(sysctl hw.ncpu 2>/dev/null | awk '{print $NF}')
    if [ -z "$THREADS" ]; then
      THREADS=$(cat /proc/cpuinfo | grep -c "^processor.*: [0-9]")
      if [ -z "$THREADS" ]; then
        echo "$PROG: --warn: weren't able to work out number of threads via \`lscpu' or \`sysctl hw.ncpu', setting to single-core test only..." >&2
        THREADS=1
      fi
    fi
  fi

  echo "* [$HOST] CPU Benchmark: running sysbench ${SYSBENCH_TEST}cpu --cpu-max-prime=$MAX_PRIME, --${THREADS_PARAM}threads=1+$THREADS"
  sysbench ${SYSBENCH_TEST}cpu --cpu-max-prime=$MAX_PRIME --${THREADS_PARAM}threads=1 run | grep -E "total time|events per second" | sed "s/$/		--> single core CPU test/"
  if [ "$THREADS" -gt 1 ]; then
    sysbench ${SYSBENCH_TEST}cpu --cpu-max-prime=$MAX_PRIME --${THREADS_PARAM}threads=$THREADS run | grep -E "total time|events per second" | sed "s/$/		--> $THREADS threads CPU test/"
  fi
  #sysbench --test=cpu --cpu-max-prime=$MAX_PRIME --num-threads=$THREADS run | grep -E "total time|events per second"
fi

#
# MEMORY TEST
#
if [ "$1" = "-memory" -o "$1" = "--memory" -o -z "$1" ]; then
  echo && echo "* [$HOST] Memory Benchmark: 2GB (read & write)"
  sleep 2

  #sysbench ${SYSBENCH_TEST}memory --memory-total-size=2G --memory-oper=read run | grep -E "total time|transferred"                 # read test
  sysbench ${SYSBENCH_TEST}memory --memory-total-size=2G run | grep -E "total time|transferred" | sed "s/$/		--> RAM write (2GB-data) speed/" # write test
  #sysbench --test=memory --memory-total-size=2G --memory-oper=read run | grep -E "total time|transferred"
  #sysbench --test=memory --memory-total-size=2G run | grep -E "total time|transferred"
fi

#
# IO TEST
#
if [ -n "$SPACE_LEFT" -o "$1" = "-io" ]; then
  if [ "$1" = "-io" -o -z "$1" ]; then
    echo && echo "* [$HOST] IO Benchmark: $SIZE_TO_TEST"
    echo -n "  - NB: using following disk: "
    df -Th . | tail -1
    sleep 2

    # drop caches to accurately measure disk speeds
    if sudo -n whoami >&/dev/null; then
      echo "  - flushing & clearing cached memory/the disk cache (Press Ctrl-C to cancel):"
      #sudo /sbin/sysctl vm.drop_caches=3
      echo "echo 3 > /proc/sys/vm/drop_caches" | sudo sh
    else
      echo "--ERROR: no sudo access on $(uname -n), skipping cache flush..." >&2
    fi

    # seqwr: sequential write
    # seqrewr: sequential read+write
    # seqrd: sequential read
    # rndrd: random read
    # rndwr: random write
    # rndrw: random read write

    echo "  - running sysbench fileio suite with $SIZE_TO_TEST of test files:"

    sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST prepare --verbosity=2
    sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST --file-test-mode=rndrw run | grep -E 'read, MiB|written, MiB|Operations performed:|Total transferred' | sed "s/$/		--> disk $SIZE_TO_TEST << random >> read+write speed/"
    sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST cleanup --verbosity=2

    sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST prepare --verbosity=2
    sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST --file-test-mode=seqrewr run | grep -E 'read, MiB|written, MiB|Operations performed:|Total transferred' | sed "s/$/		--> disk $SIZE_TO_TEST << sequential >> read+write speed/"
    sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST cleanup --verbosity=2

    echo "  - dd: $SIZE_TO_TEST_COUNT x 1M write test:"
    if echo "$OSTYPE" | grep -q darwin; then
      dd if=/dev/zero of=./tempfile bs=1048576 count=$SIZE_TO_TEST_COUNT conv=notrunc 2>&1 | grep -E -v 'records in|records out' | sed "s/$/		--> dd disk $SIZE_TO_TEST write speed/"
    else
      # dd if=/dev/zero of=/tmp/test bs=64k count=16k conv=fdatasync
      dd if=/dev/zero of=./tempfile bs=1M count=$SIZE_TO_TEST_COUNT conv=fdatasync,notrunc 2>&1 | grep -E -v 'records in|records out' | sed "s/$/		--> dd disk $SIZE_TO_TEST write speed/"
    fi

    # clean-up
    rm -f ./tempfile
  fi
fi

#
# HDPARM TEST
#
if [ "$1" = "-hdparm" ]; then
  echo && echo "* hdparm: sequential overall-drive read test on << /dev/$DEV >>:"
  sleep 2

  # drop caches to accurately measure disk speeds
  echo "  - flushing & clearing cached memory/the disk cache:"
  sudo /sbin/sysctl vm.drop_caches=3

  # work out the primary disk device
  DEV=$(lsblk 2>/dev/null | awk '/ \/$/{print $1}' | sed 's/[abcdp][0-9]$//g; s/[^a-z0-9]//g')
  [ -z "$DEV" ] && {
    echo "can't work out dev to test..." >&2
    exit 1
  }

  echo "* running: sudo hdparm -tT /dev/$DEV"
  sudo hdparm -tT /dev/$DEV | tail -1
fi

# EOF
