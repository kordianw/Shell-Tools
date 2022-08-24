#!/bin/bash
# tests CPU+Mem+IO speed using `sysbench'
# - writes test files to current dir
#
# OPTIONS:
# -ssd     <-- checks if a disk is SSD by running a quick IO test
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
PROG=`basename $0`
if [ ! -w . ]; then
  echo "$PROG: you don't have permission to test in the current dir!" >&2
  exit 1
fi

# check SSD speed - crude way ...
if [ "$1" = "-ssd" ]; then

  COUNT=2000

  # check if the root drive is SSD
  # - if SSD, cmd will take around 1 sec
  # - if HDD, cmd will take around 10 sec

  echo "* $PROG: timing $COUNT disk reads on your disks ..."
  echo "  - if it takes ~2 secs to read disk, most likely it's an SSD"
  echo "  - if it takes >5 secs to read disk, most likely it's an HDD"

  DF_CMD=`df -lTh -x tmpfs -x devtmpfs -x squashfs -x fuse.sshfs | egrep -v '/boot/efi'`

  echo && echo "* df output:"
  echo "$DF_CMD"

  if ! which lsblk >&/dev/null; then
    echo "--FATAL: you don't have \`lsblk' installed!" >&2
    echo "run: apt-get install util-linux" >&2
    exit 99
  fi

  echo && echo "* lsblk output:"
  lsblk | grep "/" |egrep -v 'loop|/boot/efi' | grep '[0-9]'
  lsblk -d -e 1,7 -o NAME,MAJ:MIN,TYPE,FSTYPE,SIZE,RO,VENDOR,MODEL,ROTA,MOUNTPOINT,GROUP,MODE | egrep -v 'CD.ROM'

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
    for a in `lsblk -d -e 1,7 -o NAME | grep -v NAME`; do
      DEV="/dev/$a"
      echo && echo "**** DEV << $DEV >>"
      time for i in `seq 1 $COUNT`; do
        $SUDO dd bs=4k if=$DEV count=1 skip=$(( $RANDOM * 128 )) >/dev/null 2>&1;
      done 2>&1 | grep real
      sleep 3
    done
  else
    echo "--FATAL: can't work out which dev to test on!" >&2
    exit 99
  fi

  ##########################################################

  exit 0
fi

if ! which sysbench >&/dev/null; then
  echo "$PROG: you don't have \`sysbench' installed; can't do any CPU performance testing!" >&2
  exit 2
fi

# allow working with less capacity
if [ "$1" = "-1GB" ]; then
  shift

  MIN_SPACE_NEEDED=1100
  SIZE_TO_TEST="1G"
  SIZE_TO_TEST_COUNT="1024"
fi

# check for space
SPACE_LEFT=`df -m . | awk '/^\/|^overlay/{print $4}'`
if [ -z "$SPACE_LEFT" ]; then
  echo "$PROG: can't calculate space left in current dir - via: \`df -m .'" >&2
  exit 98
elif [ $SPACE_LEFT -lt $MIN_SPACE_NEEDED ]; then
  echo -e "$PROG: FATAL: not enough space left in current dir - seeing $SPACE_LEFT MB, needs at least $MIN_SPACE_NEEDED MB - see below:" >&2
  df -h .
  echo -e "\nNOTE: can use \"-1GB\" param to reduce the requirements..." >&2
  exit 99
fi

##################

# show HW information if available
if which hw-info.sh >&/dev/null; then
  hw-info.sh
elif [ -x ~/src/HW-Info/hw-info.sh ]; then
  ~/src/HW-Info/hw-info.sh
fi

# sysbench: old-style of new style?
SYSBENCH_TEST=""
THREADS_PARAM=""
if `sysbench --version | grep -q "sysbench 0\."`; then
  SYSBENCH_TEST="--test="
  THREADS_PARAM="num-"
fi

# set hostname
HOST=`hostname`
[ -z "$HOST" ] && HOST=`uname -n`

#
# CPU TEST
#
if [ "$1" = "-cpu" -o -z "$1" ]; then
  # work out how many CPUs (threads) we have?
  THREADS=`lscpu 2>/dev/null |awk '/^CPU\(s\):/{print $NF}'`
  if [ -z "$THREADS" ]; then
    THREADS=`sysctl hw.ncpu 2>/dev/null | awk '{print $NF}'`
    if [ -z "$THREADS" ]; then
      THREADS=`cat /proc/cpuinfo |grep -c "^processor.*: [0-9]"`
      if [ -z "$THREADS" ]; then
        echo "$PROG: --warn: weren't able to work out number of threads via \`lscpu' or \`sysctl hw.ncpu', setting to single-core test only..." >&2
        THREADS=1
      fi
    fi
  fi

  echo "* [$HOST] CPU Benchmark: running sysbench ${SYSBENCH_TEST}cpu --cpu-max-prime=$MAX_PRIME, --${THREADS_PARAM}threads=1+$THREADS"
  sysbench ${SYSBENCH_TEST}cpu --cpu-max-prime=$MAX_PRIME --${THREADS_PARAM}threads=1 run | egrep "total time|events per second" | sed "s/$/		--> single core CPU test/"
  if [ "$THREADS" -gt 1 ]; then
    sysbench ${SYSBENCH_TEST}cpu --cpu-max-prime=$MAX_PRIME --${THREADS_PARAM}threads=$THREADS run | egrep "total time|events per second" | sed "s/$/		--> $THREADS threads CPU test/"
  fi
  #sysbench --test=cpu --cpu-max-prime=$MAX_PRIME --num-threads=$THREADS run | egrep "total time|events per second"
fi

#
# MEMORY TEST
#
if [ "$1" = "-memory" -o -z "$1" ]; then
  echo && echo "* [$HOST] Memory Benchmark: 2GB (read & write)"
  sleep 2

  #sysbench ${SYSBENCH_TEST}memory --memory-total-size=2G --memory-oper=read run | egrep "total time|transferred"                 # read test
  sysbench ${SYSBENCH_TEST}memory --memory-total-size=2G run | egrep "total time|transferred" | sed "s/$/		--> RAM write (2GB-data) speed/"  # write test
  #sysbench --test=memory --memory-total-size=2G --memory-oper=read run | egrep "total time|transferred"
  #sysbench --test=memory --memory-total-size=2G run | egrep "total time|transferred"
fi

#
# IO TEST
#
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
    echo "--ERROR: no sudo access on `uname -n`, skipping cache flush..." >&2
  fi

  # seqwr: sequential write
  # seqrewr: sequential read+write
  # seqrd: sequential read
  # rndrd: random read
  # rndwr: random write
  # rndrw: random read write

  echo "  - running sysbench fileio suite with $SIZE_TO_TEST of test files:"

  sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST prepare --verbosity=2
  sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST --file-test-mode=rndrw run |egrep 'read, MiB|written, MiB|Operations performed:|Total transferred' | sed "s/$/		--> disk $SIZE_TO_TEST << random >> read+write speed/"
  sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST cleanup --verbosity=2

  sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST prepare --verbosity=2
  sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST --file-test-mode=seqrewr run |egrep 'read, MiB|written, MiB|Operations performed:|Total transferred' | sed "s/$/		--> disk $SIZE_TO_TEST << sequential >> read+write speed/"
  sysbench ${SYSBENCH_TEST}fileio --file-total-size=$SIZE_TO_TEST cleanup --verbosity=2

  echo "  - dd: $SIZE_TO_TEST_COUNT x 1M write test:"
  if echo "$OSTYPE" |grep -q darwin; then
    dd if=/dev/zero of=./tempfile bs=1048576 count=$SIZE_TO_TEST_COUNT conv=notrunc 2>&1 |egrep -v 'records in|records out' | sed "s/$/		--> dd disk $SIZE_TO_TEST write speed/"
  else
    # dd if=/dev/zero of=/tmp/test bs=64k count=16k conv=fdatasync
    dd if=/dev/zero of=./tempfile bs=1M count=$SIZE_TO_TEST_COUNT conv=fdatasync,notrunc 2>&1 |egrep -v 'records in|records out' | sed "s/$/		--> dd disk $SIZE_TO_TEST write speed/"
  fi

  # clean-up
  rm -f ./tempfile
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
  DEV=`lsblk 2>/dev/null |awk '/ \/$/{print $1}' | sed 's/[abcdp][0-9]$//g; s/[^a-z0-9]//g'`
  [ -z "$DEV" ] && { echo "can't work out dev to test..." >&2; exit 1; }
 
  echo "* running: sudo hdparm -tT /dev/$DEV"
  sudo hdparm -tT /dev/$DEV |tail -1
fi

# EOF
