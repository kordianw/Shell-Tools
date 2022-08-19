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
    elif which nslookup >&/dev/null; then
      IP=`nslookup myip.opendns.com resolver1.opendns.com 2>/dev/null | cat -v | awk '/Address:/{print $NF}' | sed 's/[^0-9\.]*//g' |tail -1`
    else
      echo "--FATAL: no \`dig' and no \`nslookup' command!"
      exit 99
    fi
  fi

  # got the IP!
  if [ -n "$IP" ]; then
    echo "* geocoding IP << $IP >>" >&2

    # KEYCDN
    echo "--> KEYCDN.COM:"
    if which jq >&/dev/null; then
      curl -sSL -H "User-Agent: keycdn-tools:https://google.com" http://tools.keycdn.com/geo.json?host=$IP | jq . | egrep -v '^{|^}|status"|description"|data"|geo"|host":|ip":|asn":|code":|latitude":|longitude":|metro_code"|datetime":|continent_name":|^ *}'
    else
      curl -w "\n" -sSL -H "User-Agent: keycdn-tools:https://google.com" http://tools.keycdn.com/geo.json?host=$IP
    fi

    # IPINFO
    echo && echo "--> IPINFO.IO"
    curl -sSL http://ipinfo.io/$IP |egrep -v '^{|^}|"ip":|"readme":|"loc":'
    
    # WTFMYISP: bonus category
    if [ -z "$1" ]; then
      echo && echo "--> WTFMYISP.COM:"
      curl -sSL http://wtfismyip.com/json | egrep -v '^{|^}|TorExit":|CountryCode":|IPAddress":' | sed 's/.ucking//g'

      echo && echo "--> IPAPI.COM:"
      curl -sSL http://ipapi.com/json | egrep -v '"ip":|"version":|_code":|code_iso3":|capital":|tld":|"in_eu":|"latitude":|"longitude":|"utc_offset":|"country_calling_code":|"currency":|"currency_name":|"languages":|"country_area":|"country_population":|"asn":'
    fi
  else
    echo "--FATAL: couldn't work out the external IP address!" >&2
  fi
fi

# EOF
