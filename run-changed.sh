#!/bin/sh
# run a script (with params), if files have changed
# - useful for code development, where it will re-run a script once you make a change in an editor session
#
# * By Kordian Witek <code@kordian.com>, Oct 2007
#

# what file extensions do we care about?
CHECK_EXTS="*.pl *.pm *.py *.sh *.inf *.conf"


##############################################
# parse any params
if [ "$1"  = "-h" -o "$1"  = "--help" ]; then
  echo -e "`basename $0`: re-run script if script files have changed.\n\nUsage:\n\t`basename $0` [-extra <file>] <script> [param1,param2,...]\n\nFiles checked: $CHECK_EXTS, -extra <file>" 1>&2
  exit 1
elif [ "$1" = "-extra" ]; then
  # any extra file to also watch, in addition to CHECK_EXTS?
  EXTRAS="$2"
  shift; shift
fi

# are we executable?
if [ ! -x "$1" ]; then
  echo "$0: supplied param <$1> is not executable, aborting..." 1>&2
  exit 1
fi

# what is the compare cmd?
COMPARE_CMD="/bin/ls -l --time-style=full-iso $CHECK_EXTS $EXTRAS 2>/dev/null"

# multiple files, last-mod date
while true; do
  while [ "`eval $COMPARE_CMD`" != "$FILES" -o ! -x "$1" ]; do
    # wait until it's executable
    while [ ! -x "$1" ]; do
      echo "*** waiting for <$1> to become executable..." 1>&2
      sleep 1
    done

    FILES=`eval $COMPARE_CMD`
    echo "======================================================== `date "+%H:%M"` ===" 1>&2
    START=`date +%s`

    #
    # EXEC
    #
    $@
    RC=$?

    DIFF=$(( `date +%s` - $START ))
    echo "<<< Time: $DIFF sec(s) @ `date +%H:%M` >>>" 1>&2

    echo "======================================================== RC=$RC ===" 1>&2
  done
  FILES=`eval $COMPARE_CMD`

  # SLEEP 1 SECOND
  sleep 1
done

# EOF
