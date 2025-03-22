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
PROG=$(basename $0)
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
    if command -v dig >&/dev/null; then
      #
      # DIG
      # - myip.opendns.com
      # - whoami.akamai.net
      # - google
      #
      IP=$(timeout 3 dig +short myip.opendns.com @resolver1.opendns.com. | grep -E '[0-9]')
      if [ $? -ne 0 ]; then
        echo "--WARN: can't work out external/public IP address via cmd (RC=$?): dig +short myip.opendns.com @resolver1.opendns.com." >&2
      fi

      # 2nd attempt via another provider
      if [ -z "$IP" ]; then
        IP=$(timeout 2 dig +short whoami.akamai.net @ns1-1.akamaitech.net. | grep -E '[0-9]')
        if [ $? -ne 0 ]; then
          echo "--WARN: can't work out external/public IP address via cmd (RC=$?): dig +short whoami.akamai.net." >&2
        fi
      fi

      # 3rd attempt via another provider
      if [ -z "$IP" ]; then
        IP=$(timeout 2 dig txt o-o.myaddr.test.l.google.com @ns1.google.com. +short | grep -E '[0-9]')
        if [ $? -ne 0 ]; then
          echo "--WARN: can't work out external/public IP address via cmd (RC=$?): dig txt o-o.myaddr.test.l.google.com. @ns1.google.com +short.akamai.net" >&2
        fi
      fi
    elif command -v nslookup >&/dev/null; then
      #
      # NSLOOKUP
      #
      IP=$(timeout 3 nslookup myip.opendns.com resolver1.opendns.com 2>/dev/null | tail +3 | cat -v | awk '/Address:/{print $NF}' | sed 's/[^0-9\.]*//g' | grep -E '[0-9]' | tail -1)
      if [ $? -ne 0 ]; then
        echo "--WARN: can't work out external/public IP address via cmd (RC=$?): nslookup myip.opendns.com resolver1.opendns.com" >&2
      fi
    elif command -v curl >&/dev/null; then
      IP=""
      [ -z "$IP" ] && IP=$(timeout 4 curl -sSL http://ipecho.net/plain 2>/dev/null)
      [ -z "$IP" ] && IP=$(timeout 4 curl -sSL http: ifconfig.me 2>/dev/null)
    else
      echo "--ERROR: no \`dig', no \`nslookup' and no \`curl' command on $(uname -n):" >&2
      which dig 1>&2
      which nslookup 1>&2
      which host 1>&2
    fi
  fi

  # alternative method of getting the IP
  if [ -z "$IP" ]; then
    if command -v curl >&/dev/null; then
      IP=""
      [ -z "$IP" ] && IP=$(timeout 4 curl -k -sSL http://ipecho.net/plain 2>/dev/null)
      [ -z "$IP" ] && IP=$(timeout 4 curl -k -sSL http: ifconfig.me 2>/dev/null)
    fi
  fi

  # got the IP!
  if [ -n "$IP" ]; then
    if ! grep -q '[0-9][0-9]' <<<$IP; then
      echo "--FATAL: worked out external/public IP << $IP >> doesn't looks like a valid IP!" >&2
      exit 99
    fi

    # IP looks ok!
    echo "* attempting to geo-locate external/public IP Address << $IP >> ..."

    # KEYCDN
    echo "--> KEYCDN.COM:"
    if command -v jq >&/dev/null; then
      timeout 5 curl -k -sSL -H "User-Agent: keycdn-tools:https://google.com" http://tools.keycdn.com/geo.json?host=$IP | jq . | grep -E -v '^{|^}|status"|description"|data"|geo"|host":|ip":|asn":|code":|latitude":|longitude":|metro_code"|datetime":|continent_name":|: null,|^ *}'
    else
      timeout 5 curl -k -w "\n" -sSL -H "User-Agent: keycdn-tools:https://google.com" http://tools.keycdn.com/geo.json?host=$IP
    fi

    # IPINFO
    echo && echo "--> IPINFO.IO:"
    timeout 5 curl -k -sSL http://ipinfo.io/$IP | grep -E -v '^{|^}|"ip":|"readme":|"loc":'

    # IPLOCATION.NET
    # - via links/lynx/w3m
    CLI_BROWSER=$(command -v links 2>/dev/null) # use `links' by default as the text-only browser
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/links ] && CLI_BROWSER=~/bin/links
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/links-2.12 ] && CLI_BROWSER=~/bin/links-2.12

    [ ! -x "$CLI_BROWSER" ] && CLI_BROWSER=$(command -v lynx 2>/dev/null)
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/lynx ] && CLI_BROWSER=~/bin/lynx

    [ ! -x "$CLI_BROWSER" ] && CLI_BROWSER=$(command -v lynxlet 2>/dev/null)
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/lynxlet ] && CLI_BROWSER=~/bin/lynxlet

    [ ! -x "$CLI_BROWSER" ] && CLI_BROWSER=$(command -v w3m 2>/dev/null)
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/w3m ] && CLI_BROWSER=~/bin/w3m

    if [ -n "$CLI_BROWSER" -a -x "$CLI_BROWSER" ]; then
      # ignore invalid SSL certs with links
      if grep -q links <<<$CLI_BROWSER; then
        CLI_BROWSER="$CLI_BROWSER -ssl.certificates 0"
      fi

      echo && echo "--> IPLOCATION.NET:"
      timeout 5 $CLI_BROWSER -dump http://iplocation.net | grep -E 'IP Location .*Details|Host Name |ISP  '

      echo && echo "--> IPLOCATION.COM:"
      timeout 5 $CLI_BROWSER -dump https://iplocation.com | grep -E 'Country  |Region  |City  |Organization  '
    else
      echo && echo "--warn: skipping IPLOCATION.NET/COM as $(uname -n 2>/dev/null) doesn't have \`links', \`lynx' or \`w3m' text-only browser installed!" >&2
    fi

    # WTFMYIP: bonus category
    # - when getting current IP (no params)
    if [ -z "$1" ]; then
      echo && echo "--> WTFMYIP.COM:"
      OUT1=$(timeout 5 curl -k -sSL http://wtfismyip.com/json | grep -E -v '^{|^}|TorExit":|CountryCode":|IPAddress":' | sed 's/.ucking//g')
      [ -z "$OUT1" ] && $CLI_BROWSER -dump http://wtfismyip.com/json 2>/dev/null
      [ -n "$OUT1" ] && echo "$OUT1"

      echo && echo "--> IPAPI.CO:"
      OUT2=$(timeout 5 curl -k -sSL http://ipapi.co/json | grep -E -v '^{|^}|"ip":|"version":|_code":|code_iso3":|capital":|tld":|"in_eu":|"latitude":|"longitude":|"utc_offset":|"country_calling_code":|"currency":|"currency_name":|"languages":|"country_area":|"country_population":|"asn":|"country": ')
      [ -z "$OUT2" ] && $CLI_BROWSER -dump http://ipapi.co/json 2>/dev/null
      [ -n "$OUT2" ] && echo "$OUT2"
    else
      echo "--warn: skipping WTFMYIP.COM & IPAPI.CO as these can only be used on CURRENT IP, rather than PARAM IP!" >&2
    fi
  else
    echo "--WARN: couldn't work out the external IP address!" >&2

    echo && echo "--BACKUP MODE: will try to geo-code using \`curl' and external websites:" >&2

    echo && echo "--> WTFISMYIP.COM:"
    OUT1=$(timeout 5 curl -k -sSL http://wtfismyip.com/json | grep -E -v '^{|^}|TorExit":|CountryCode":|IPAddress":' | sed 's/.ucking//g')
    [ -z "$OUT1" ] && $CLI_BROWSER -dump http://wtfismyip.com/json 2>/dev/null
    [ -n "$OUT1" ] && echo "$OUT1"

    echo && echo "--> IPAPI.CO:"
    OUT2=$(timeout 5 curl -k -sSL http://ipapi.co/json | grep -E -v '^{|^}|"ip":|"version":|_code":|code_iso3":|capital":|tld":|"in_eu":|"latitude":|"longitude":|"utc_offset":|"country_calling_code":|"currency":|"currency_name":|"languages":|"country_area":|"country_population":|"asn":|"country": ')
    [ -z "$OUT2" ] && $CLI_BROWSER -dump http://ipapi.co/json 2>/dev/null
    [ -n "$OUT2" ] && echo "$OUT2"

    # IPLOCATION.COM/NET
    # - via links/lynx/w3m
    CLI_BROWSER=$(command -v links 2>/dev/null) # use `links' by default as the text-only browser
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/links ] && CLI_BROWSER=~/bin/links
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/links-2.12 ] && CLI_BROWSER=~/bin/links-2.12

    [ ! -x "$CLI_BROWSER" ] && CLI_BROWSER=$(command -v lynx 2>/dev/null)
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/lynx ] && CLI_BROWSER=~/bin/lynx

    [ ! -x "$CLI_BROWSER" ] && CLI_BROWSER=$(command -v lynxlet 2>/dev/null)
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/lynxlet ] && CLI_BROWSER=~/bin/lynxlet

    [ ! -x "$CLI_BROWSER" ] && CLI_BROWSER=$(command -v w3m 2>/dev/null)
    [ ! -x "$CLI_BROWSER" -a -x ~/bin/w3m ] && CLI_BROWSER=~/bin/w3m

    if [ -n "$CLI_BROWSER" -a -x "$CLI_BROWSER" ]; then
      # ignore invalid SSL certs with links
      if grep -q links <<<$CLI_BROWSER; then
        CLI_BROWSER="$CLI_BROWSER -ssl.certificates 0"
      fi

      echo && echo "--> IPLOCATION.NET:"
      timeout 5 $CLI_BROWSER -dump http://iplocation.net | grep -E 'IP Location .*Details|Host Name |ISP  '

      echo && echo "--> IPLOCATION.COM:"
      timeout 5 $CLI_BROWSER -dump https://iplocation.com | grep -E 'Country  |Region  |City  |Organization  '
    else
      echo && echo "--warn: skipping IPLOCATION.NET/COM as $(uname -n 2>/dev/null) doesn't have \`links', \`lynx' or \`w3m' text-only browser installed!" >&2
    fi

    # partial successs
    exit 1
  fi
fi

# EOF
