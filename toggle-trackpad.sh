#!/bin/sh
# toggle a laptop trackpad on/off via `xinput'
# - useful for when typing for long periods of time
#
# * By Kordian W. <code [at] kordy.com>, Apr 2020
#

# check we have xinput
[ -x /usr/bin/xinput ] || { echo "No \`xinput' binary on `hostname` - nothing to do!" >&2; exit 1; }

# get ID
ID=`xinput list | grep -i 'Touchpad.*id=' | tail -1 | sed 's/.*id=\([0-9]*\)\t.*/\1/'`
[ -n "$ID" ] || { echo "Can't work out Touchpad ID via \'xinput list'!" >&2; exit 2; }

# work out current state
CURRENT_STATE=`xinput list-props $ID | awk '/Device Enabled/{print $NF}'`
[ -n "$CURRENT_STATE" ] || { echo "Can't work out current state of ID=$ID via \'xinput list-props $ID'!" >&2; exit 2; }

# toggle
TOGGLE=0
[ "$CURRENT_STATE" -eq 0 ] && TOGGLE=1

#
# EXEC
#
set -x
xinput set-prop $ID "Device Enabled" $TOGGLE || exit 1

# EOF
