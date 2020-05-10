#!/bin/bash
# tests CPU+Mem+IO speed using `sysbench'
# - writes test files to current dir
#
# * By Kordian Witek <code [at] kordy.com>, Jan 2020
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

if ! which sysbench >&/dev/null; then
  echo "$PROG: you don't have \`sysbench' installed; can't do any CPU performance testing!" >&2
  exit 2
fi

# allow working with less capacity
if [ "$1" = "-1GB" ]; then
  shift

  MIN_SPACE_NEEDED=1500
  SIZE_TO_TEST="1G"
  SIZE_TO_TEST_COUNT="1024"
fi

# check for space
SPACE_LEFT=`df -m . | awk '/^\//{print $4}'`
if [ -z "$SPACE_LEFT" ]; then
  echo "$PROG: can't calculate space left in current dir - via: df -m ." >&2
  exit 98
elif [ $SPACE_LEFT -lt $MIN_SPACE_NEEDED ]; then
  echo -e "$PROG: FATAL: not enough space left in current dir - seeing $SPACE_LEFT MB, needs at least $MIN_SPACE_NEEDED MB - see below:" >&2
  df -h .
  echo -e "\nNOTE: can use \"-1GB\" param to reduce the requirements..." >&2
  exit 99
fi

##################


#
# CPU TEST
#
if [ "$1" = "-cpu" -o -z "$1" ]; then
  # work out how many CPUs (threads) we have?
  THREADS=`lscpu 2>/dev/null |awk '/^CPU\(s\):/{print $NF}'`
  if [ -z "$THREADS" ]; then
    THREADS=`sysctl hw.ncpu 2>/dev/null | awk '{print $NF}'`
    if [ -z "$THREADS" ]; then
      echo "$PROG: --warn: weren't able to work out number of threads via \`lscpu' or \`sysctl hw.ncpu', setting to single-core test only..." >&2
      THREADS=1
    fi
  fi

  echo "* [`hostname`] CPU Benchmark: running sysbench, --cpu-max-prime=$MAX_PRIME, --threads=1+$THREADS"
  sysbench cpu --cpu-max-prime=$MAX_PRIME --threads=1 run | egrep "total time|events per second" | sed "s/$/		--> single core CPU test/"
  if [ "$THREADS" -gt 1 ]; then
    sysbench cpu --cpu-max-prime=$MAX_PRIME --threads=$THREADS run | egrep "total time|events per second" | sed "s/$/		--> $THREADS threads CPU test/"
  fi
  #sysbench --test=cpu --cpu-max-prime=$MAX_PRIME --num-threads=$THREADS run | egrep "total time|events per second"
fi

#
# MEMORY TEST
#
if [ "$1" = "-memory" -o -z "$1" ]; then
  echo && echo "* [`hostname`] Memory Benchmark: 2GB (read & write)"
  sleep 2

  #sysbench memory --memory-total-size=2G --memory-oper=read run | egrep "total time|transferred"                 # read test
  sysbench memory --memory-total-size=2G run | egrep "total time|transferred" | sed "s/$/		--> RAM write (2GB-data) speed/"  # write test
  #sysbench --test=memory --memory-total-size=2G --memory-oper=read run | egrep "total time|transferred"
  #sysbench --test=memory --memory-total-size=2G run | egrep "total time|transferred"
fi

#
# IO TEST
#
if [ "$1" = "-io" -o -z "$1" ]; then
  echo && echo "* [`hostname`] IO Benchmark: $SIZE_TO_TEST"
  sleep 2

  # drop caches to accurately measure disk speeds
  echo "  - flushing & clearing cached memory/the disk cache (Press Ctrl-C to cancel):"
  sudo /sbin/sysctl vm.drop_caches=3

  # seqwr: sequential write
  # seqrewr: sequential read+write
  # seqrd: sequential read
  # rndrd: random read
  # rndwr: random write
  # rndrw: random read write

  echo "  - running sysbench fileio suite with $SIZE_TO_TEST of test files:"
  sysbench fileio --file-total-size=$SIZE_TO_TEST prepare --verbosity=2
  sysbench fileio --file-total-size=$SIZE_TO_TEST --file-test-mode=rndrw run |egrep 'read, MiB|written, MiB|Operations performed:|Total transferred' | sed "s/$/		--> disk $SIZE_TO_TEST random read+write speed/"
  sysbench fileio --file-total-size=$SIZE_TO_TEST cleanup --verbosity=2

  echo "  - dd: $SIZE_TO_TEST_COUNT x 1M write test:"
  if [[ "$OSTYPE" == darwin* ]]; then
    dd if=/dev/zero of=./tempfile bs=1048576 count=$SIZE_TO_TEST_COUNT conv=notrunc 2>&1 |egrep -v 'records in|records out' | sed "s/$/		--> dd disk $SIZE_TO_TEST write speed/"
  else
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
  DEV=`lsblk 2>/dev/null |awk '/ \/$/{print $1}' | sed 's/[^a-z]//g'`
  [ -z "$DEV" ] && { echo "can't work out dev to test..." >&2; exit 1; }
 
  sudo hdparm -tT /dev/$DEV |tail -1
fi

# EOF
