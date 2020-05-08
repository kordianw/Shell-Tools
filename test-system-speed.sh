#!/bin/bash
# tests CPU+Mem+IO speed using `sysbench'
# - writes test files to current dir
#
# * By Kordian Witek <code [at] kordy.com>, Jan 2020
#

# maximum number prime to calculate - this usually takes around 1-2mins so is a perfect test
MAX_PRIME=20000


##################
if ! which sysbench >&/dev/null; then
  echo "$0: you don't have \`sysbench' installed; can't do any CPU performance testing!" >&2
  exit 1
fi

# CPU
if [ "$1" = "-cpu" -o -z "$1" ]; then
  # work out how many CPUs (threads) we have?
  THREADS=`lscpu |awk '/^CPU\(s\):/{print $NF}'`
  [ -z "$THREADS" ] && { echo "$0: weren't able to work out number of threads via \`lscpu'!" >&2; exit 1; }

  echo "* [`hostname`] CPU Benchmark: running sysbench, --cpu-max-prime=$MAX_PRIME, --threads=$THREADS"
  sysbench cpu --cpu-max-prime=$MAX_PRIME --threads=$THREADS run | egrep "total time|events per second"
  #sysbench --test=cpu --cpu-max-prime=$MAX_PRIME --num-threads=$THREADS run | egrep "total time|events per second"
fi

# MEMORY
if [ "$1" = "-memory" -o -z "$1" ]; then
  echo && echo "* [`hostname`] Memory Benchmark: 2GB (read & write)"
  sysbench memory --memory-total-size=2G --memory-oper=read run | egrep "total time|transferred"
  sysbench memory --memory-total-size=2G run | egrep "total time|transferred"
  #sysbench --test=memory --memory-total-size=2G --memory-oper=read run | egrep "total time|transferred"
  #sysbench --test=memory --memory-total-size=2G run | egrep "total time|transferred"
fi

# check for space
SPACE_LEFT=`df -m . | awk '/^\//{print $4}'`
if [ -z "$SPACE_LEFT" ]; then
  echo "$0: can't calculate space left in current dir - via: df -m ." >&2
  exit 98
elif [ $SPACE_LEFT -lt 2500 ]; then
  echo -e "\n$0: FATAL: not enough space left in current dir - seeing $SPACE_LEFT MB, needs at least 2.5GB - see below:" >&2
  df -h .
  exit 99
else
  df -h . |tail -1
fi

# IO
if [ "$1" = "-io" -o -z "$1" ]; then
  echo && echo "* [`hostname`] IO Benchmark: 2GB"

  # drop caches to accurately measure disk speeds
  echo "  - flushing & clearing cached memory/the disk cache:"
  sudo /sbin/sysctl vm.drop_caches=3

  sysbench fileio --file-total-size=2G prepare --verbosity=2
  sysbench fileio --file-total-size=2G --file-test-mode=rndrw run |egrep 'read, MiB|written, MiB|Operations performed:|Total transferred'
  sysbench fileio --file-total-size=2G cleanup --verbosity=2

  echo "  - dd: 2GB write test:"
  dd if=/dev/zero of=./tempfile bs=1M count=2048 conv=fdatasync,notrunc status=progress 2>&1 |egrep -v 'records in|records out'
  rm -f ./tempfile

fi

# HDPARM
if [ "$1" = "-hdparm" ]; then
  echo && echo "* hdparm: sequential overall-drive read test on << /dev/$DEV >>:"

  # drop caches to accurately measure disk speeds
  echo "  - flushing & clearing cached memory/the disk cache:"
  sudo /sbin/sysctl vm.drop_caches=3

  # work out the primary disk device
  DEV=`lsblk 2>/dev/null |awk '/ \/$/{print $1}' | sed 's/[^a-z]//g'`
  [ -z "$DEV" ] && { echo "can't work out dev to test..." >&2; exit 1; }
 
  sudo hdparm -tT /dev/$DEV |tail -1
fi

# EOF
