#!/bin/bash
#
# Script to work out the geo-location of an IP address - via geocoding, using multiple sources
#
# RUN DIRECTLY FROM GITHUB:
# $ curl -sSL https://github.com/kordianw/Shell-Tools/raw/master/ip-location.sh | bash
#
#
# * By Kordian W. <code [at] kordy.com>, August 2022
#

####################
PROG=`basename $0`
if [ "$1" = "-h" -o "$1" = "--help" ]; then
  cat <<! >&2
$PROG: Script to work out the geo-location of an IP address
       - via geocoding, using multiple sources

Usage: $PROG [options] [IP]
	-h	this screen

        NB: defaults to current external/public IP address
!
else
  IP="$1"
  if [ -z "$IP" ]; then
    if which dig >&/dev/null; then
      #
      # DIG
      #
      #IP=`dig +short whoami.akamai.net.`
      IP=`dig +short myip.opendns.com @resolver1.opendns.com.`
      if [ $? -ne 0 ]; then
        echo "--FATAL: can't work out external/public IP address via cmd (RC=$?): dig +short myip.opendns.com @resolver1.opendns.com." >&2
        exit 97
      fi
    elif which nslookup >&/dev/null; then
      #
      # NSLOOKUP
      #
      IP=`nslookup myip.opendns.com resolver1.opendns.com 2>/dev/null | cat -v | awk '/Address:/{print $NF}' | sed 's/[^0-9\.]*//g' |tail -1`
      if [ $? -ne 0 ]; then
        echo "--FATAL: can't work out external/public IP address via cmd (RC=$?): nslookup myip.opendns.com resolver1.opendns.com" >&2
        exit 98
      fi
    else
      echo "--FATAL: no \`dig' and no \`nslookup' command on `uname -n`:" >&2
      which dig
      which nslookup
      which host
      exit 99
    fi
  fi

  # got the IP!
  if [ -n "$IP" ]; then
    if ! echo "$IP" | grep -q '[0-9][0-9]'; then
      echo "--FATAL: worked out external/public IP << $IP >> doesn't looks like a valid IP!" >&2
      exit 99
    fi

    # IP looks ok!
    echo "* attempting to geo-locate external/public IP Address << $IP >> ..." >&2

    # KEYCDN
    echo "--> KEYCDN.COM:"
    if which jq >&/dev/null; then
      curl -sSL -H "User-Agent: keycdn-tools:https://google.com" http://tools.keycdn.com/geo.json?host=$IP | jq . | egrep -v '^{|^}|status"|description"|data"|geo"|host":|ip":|asn":|code":|latitude":|longitude":|metro_code"|datetime":|continent_name":|^ *}'
    else
      curl -w "\n" -sSL -H "User-Agent: keycdn-tools:https://google.com" http://tools.keycdn.com/geo.json?host=$IP
    fi

    # IPINFO
    echo && echo "--> IPINFO.IO:"
    curl -sSL http://ipinfo.io/$IP |egrep -v '^{|^}|"ip":|"readme":|"loc":'

    # IPLOCATION.NET
    # - via links/lynx/w3m
    CLI_BROWSER=`which links 2>/dev/null`       # use `links' by default as the text-only browser
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/links ] && CLI_BROWSER=~/bin/links
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/links-2.12 ] && CLI_BROWSER=~/bin/links-2.12

    [ ! -x "$CLI_BROWSER" ] && CLI_BROWSER=`which lynx 2>/dev/null`
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/lynx ] && CLI_BROWSER=~/bin/lynx

    [ ! -x "$CLI_BROWSER" ] && CLI_BROWSER=`which lynxlet 2>/dev/null`
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/lynxlet ] && CLI_BROWSER=~/bin/lynxlet

    [ ! -x "$CLI_BROWSER" ] && CLI_BROWSER=`which w3m 2>/dev/null`
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/w3m ] && CLI_BROWSER=~/bin/w3m

    if [ -n "$CLI_BROWSER" -a -x "$CLI_BROWSER" ]; then
      echo && echo "--> IPLOCATION.NET:"
      $CLI_BROWSER -dump http://iplocation.net | egrep 'IP Location .*Details|Host Name |ISP  '

      echo && echo "--> IPLOCATION.COM:"
      $CLI_BROWSER -dump http://iplocation.com | egrep 'Country  |Region  |City  |Organization  '
    else
      echo && echo "--warn: skipping IPLOCATION.NET/COM as `uname -n 2>/dev/null` doesn't have \`links', \`lynx' or \`w3m' text-only browser installed!" >&2
    fi
    
    # WTFMYISP: bonus category
    # - when getting current IP (no params)
    if [ -z "$1" ]; then
      echo && echo "--> WTFMYISP.COM:"
      curl -sSL http://wtfismyip.com/json | egrep -v '^{|^}|TorExit":|CountryCode":|IPAddress":' | sed 's/.ucking//g'

      echo && echo "--> IPAPI.CO:"
      curl -sSL http://ipapi.co/json | egrep -v '^{|^}|"ip":|"version":|_code":|code_iso3":|capital":|tld":|"in_eu":|"latitude":|"longitude":|"utc_offset":|"country_calling_code":|"currency":|"currency_name":|"languages":|"country_area":|"country_population":|"asn":|"country": '
    else
      echo "--warn: skipping WTFMYISP.COM & IPAPI.CO as these can only be used on CURRENT IP, rather than PARAM IP!" >&2
    fi
  else
    echo "--FATAL: couldn't work out the external IP address!" >&2
  fi
fi

# EOF
