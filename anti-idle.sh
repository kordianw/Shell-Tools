#!/bin/bash
# Simple anti-idle - prevents the Power Management from kicking in
#
# FUNCTION 1: sends a dummy key event every mnute
# - uses `xdotool' to send a dummy key press every 60 seconds
# - prevents ALL power management functions from kicking in
#
# FUNCTION 2: keep display brightness at maximum (eg: for watching a movie)
# - ignores all other DPMS settings and performs a temporary override
# - keeps the brightnes up for up X hours, default=3 (perfect for a movie)
# - leaves no permanent record
#
# * By Kordian Witek <code [at] kordy.com>, May 2020
#

# how many hours to keep the brightness up?
# - default is 2 hours, which is perfect for a movie
MAX_HOURS=2

#########################

#
# FUNCTIONS
#
function keep_brightness_up()
{
  # work out the backlight/display driver
  [ -e /sys/class/backlight/acpi_video0/max_brightness ] && DRIVER=acpi_video0
  [ -e /sys/class/backlight/intel_backlight/max_brightness ] && DRIVER=intel_backlight
  [ -z "$DRIVER" ] && { echo "$PROG: can't work out the video backlight driver via /sys/class/backlight/*!" >&2; exit 99; }

  MAX_BRIGHTNESS=`cat /sys/class/backlight/$DRIVER/max_brightness 2>/dev/null`
  [ -z "$MAX_BRIGHTNESS" ] && { echo "$0: can't work out max brightness via /sys/class/backlight/$DRIVER/max_brightness!" >&2; exit 99; }

  echo "* checking current brightness level (may require sudo)..."
  sudo cat /sys/class/backlight/$DRIVER/brightness || exit 9

  MAX_MINS=$(( $MAX_HOURS * 60 ))
  for (( i=1; i<=$MAX_MINS; i++ ))
  do  
    echo -n "Run #$i/$MAX_MINS mins: setting $DRIVER brightness to max: $MAX_BRIGHTNESS and waiting 60 secs: "
    echo $MAX_BRIGHTNESS |sudo tee /sys/class/backlight/$DRIVER/brightness

    # sleep 1 min
    sleep 60
  done
}

function send_dummy_key_event ()
{
  # need xdotool
  which xdotool >&/dev/null || { echo "$PROG: no \`xdotool' utility installed!" >&2; exit 1; }

  # need display
  [ -z "$DISPLAY" ] && { echo "$PROG: no DISPLAY variable - are you logged in under an X Server?!" >&2; exit 9; }

  MAX_MINS=$(( $MAX_HOURS * 60 ))
  for (( i=1; i<=$MAX_MINS; i++ ))
  do  
    echo "Run #$i/$MAX_MINS mins: sending a dummy key event and waiting 60 secs..."
    #xdotool mousemove 0 0 || exit 99
    xdotool key VoidSymbol || exit 99

    # sleep 1 min
    sleep 60
  done
}

#
# MAIN PROGRAM
#
PROG=`basename $0`
if [ "$1" = "-max_bright" ]; then
  keep_brightness_up
elif [ "$1" = "-dummy_event" ]; then
  send_dummy_key_event
else
  cat <<! >&2
$PROG: Simple anti-idle script

Usage: $PROG [options] <function>

        -max_bright

           Keeps the screen brightness at maximum for $MAX_HOURS hrs
           by changing the brightness to 100%, every minute

        -dummy_event

           Keeps sending a dummy key event every minute, for $MAX_HOURS hrs

        -h      this screen

!
fi

# EOF
