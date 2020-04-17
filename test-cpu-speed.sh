#!/bin/bash
# tests CPU speed using `sysbench', taking into account number of threads
#
# * By Kordian Witek <code [at] kordy.com>, Jan 2020
#

# maximum number prime to calculate - this usually takes around 1-2mins so is a perfect test
MAX_PRIME=20000

##################
if ! which sysbench >&/dev/null; then
  echo "$0: you don't have \`sysbench' installed; can't do any CPU testing!" >&2
  exit 1
fi

# work out how many CPUs (threads) we have?
THREADS=`lscpu |awk '/^CPU\(s\):/{print $NF}'`
[ -z "$THREADS" ] && { echo "$0: weren't able to work out number of threads via \`lscpu'!" >&2; exit 1; }

# CPU
echo "* CPU Benchmark: running sysbench, --cpu-max-prime=$MAX_PRIME, --threads=$THREADS"
#sysbench cpu --cpu-max-prime=$MAX_PRIME --threads=$THREADS run | egrep "total time|events per second"
sysbench --test=cpu --cpu-max-prime=$MAX_PRIME --num-threads=$THREADS run | egrep "total time|events per second"

# MEMORY
if [ "$1" = "-memory" -o "$1" = "-all" ]; then
  echo && echo "* Memory Benchmark: 2GB (read & write)"
  #sysbench memory --memory-total-size=2G --memory-oper=read run | grep "total time"
  #sysbench memory --memory-total-size=2G run | grep "total time"
  sysbench --test=memory --memory-total-size=2G --memory-oper=read run | egrep "total time"
  sysbench --test=memory --memory-total-size=2G run | grep "total time"
fi

# IO
if [ "$1" = "-io" -o "$1" = "-all" ]; then
  echo && echo "* IO Benchmark: 2GB"
  sysbench fileio --file-total-size=2G prepare --verbosity=2
  sysbench fileio --file-total-size=2G --file-test-mode=rndrw run |egrep 'read, MiB|written, MiB'
  sysbench fileio --file-total-size=2G cleanup --verbosity=2
fi

# EOF
