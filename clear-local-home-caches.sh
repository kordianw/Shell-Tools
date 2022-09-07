#!/bin/bash
# clears local cache dirs on Linux - saves space

#
# FUNCTIONS
#
function report_cache() {
  df -Th ~/.cache

  echo -en "* Chrome:\t"
  du -sh ~/.cache/chromium

  echo -en "* Firefox:\t"
  du -sh ~/.cache/mozilla

  echo -en "* Python PIP:\t"
  du -sh ~/.cache/pip

  echo
}

#
# MAIN
#
if [ ! -e ~/.cache ]; then
  echo "* Cache dir [~/.cache] not present on this system!" >&2
  exit 1
elif [ ! -d ~/.cache/chromium -a ! -d ~/.cache/mozilla -a ! -d ~/.cache/pip ]; then
  echo "* Caches [~/.cache/chromium, ~/.cache/mozilla, ~/.cache/pip] already cleaned!" >&2
  du -sh ~/.cache/* | sort -rn | egrep -v '^[0-9][0-9]*K|^8.0K|^4.0K|^0'
  exit 2
fi

report_cache

# CLEAN:
echo "...CLEARING..."
rm -r ~/.cache/chromium ~/.cache/mozilla ~/.cache/pip
RC=$?
echo -e "Done: RC=$RC\n"

report_cache

# EOF
