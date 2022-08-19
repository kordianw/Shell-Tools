#!/bin/bash
#
# Script to work out the the geo-location of an IP address - geocoding
#
# * By Kordian W. <code [at] kordy.com>, August 2022
# $Id$
#
# * Change Log:
# $Log$

####################
PROG=`basename $0`
if [ "$1" = "-h" -o "$1" = "--help" ]; then
  cat <<! >&2
$PROG: Script to work out the the geo-location of an IP address

Usage: $PROG [options] [IP]
	-h	this screen

        NB: defaults to current external IP address
!
else
  IP="$1"
  if [ -z "$IP" ]; then
    if which dig >&/dev/null; then
      #IP=`dig +short whoami.akamai.net.`
      IP=`dig +short myip.opendns.com @resolver1.opendns.com.`
    else
      IP=`nslookup myip.opendns.com resolver1.opendns.com | awk '/Address:/{print $NF}' |tail -1`
  fi

  if [ -n "$IP" ]; then
    echo "* geocoding IP << $IP >>" >&2
    curl ipinfo.io/$IP
    curl https://tools.keycdn.com/geo.json?host=$IP
    curl -H "User-Agent: keycdn-tools:https://google.com" https://tools.keycdn.com/geo.json?host=$IP
    curl -w "\n" -sS http://ipinfo.io/$IP
    #curl wtfismyip.com/json
  else
    echo "--FATAL: couldn't work out the external IP address!" >&2
  fi
fi

# EOF
