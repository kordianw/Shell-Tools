#!/bin/bash
#
# Script to generate NordVPN WireGuard config
#
# * By Kordian W. <code [at] kordy.com>, August 2024
#

# 1) go to: https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/  and create an access token
# 2) get your private key, using the access token:
# curl -s -u token:<ACCESS_TOKEN> https://api.nordvpn.com/v1/users/services/credentials | jq -r .nordlynx_private_key
# 3) enter the private key into the config below

# CONFIG
MY_KEY="9Y7BW1x+XWumHbr8Rfv+CUu5mfN79UidPUsPfjoP1cY="

####################
PROG=$(basename $0)
if [ $# -eq 0 -o "$1" = "-h" -o "$1" = "--help" ]; then
  cat <<! >&2
$PROG: Script to generate NordVPN WireGuard config

Usage: $PROG [options] <param>
	-uk	create a UK location / IP address config
	-us	create a USA location / IP address config
	-pl	create a PL location / IP address config
	-h	this screen
!
else
  COUNTRY=
  [ "$1" = "-uk" ] && COUNTRY=227
  [ "$1" = "-us" ] && COUNTRY=228
  [ "$1" = "-pl" ] && COUNTRY=174
  [ -e "$COUNTRY" ] && ( echo "$PROG: no country specified! see --help" 1>&2; exit 99; )

  # temp file
  TMP=/tmp/$PROG-$$

  # get the best server
  curl -s "https://api.nordvpn.com/v1/servers/recommendations?&filters\[servers_technologies\]\[identifier\]=wireguard_udp&limit=1&filters\[country_id\]=$COUNTRY"|jq -r '.[]|.hostname, .station, (.locations|.[]|.country|.city.name), (.locations|.[]|.country|.name), (.technologies|.[].metadata|.[].value), .load' > $TMP

  if [ ! -s "$TMP" ]; then
    echo "$PROG: no NordVPN output!" 1>&2
    exit 99
  fi

  # us6352.nordvpn.com
  # 91.132.137.115
  # New York
  # United States
  # 0/x2PdBGfcIGr0ayFPFFjxcEEyhrlBRjR4kMcfwXJTU=
  # 17

  SERVER=`head -1 $TMP`
  IP=`head -2 $TMP | tail -1`
  CITY=`head -3 $TMP | tail -1`
  COUNTRY=`head -4 $TMP | tail -1`

  NORD_KEY=`tail -2 $TMP | head -1`
  LOAD=`tail -1 $TMP`

  SHORT_SERVER=`echo $SERVER | awk -F. '{print $1}'`
  #OUT_CONFIG_FILE="nordvpn$1-$SHORT_SERVER-wireguard.conf"
  OUT_CONFIG_FILE="nordvpn$1-wireguard.conf"

  echo "- Server -> $SERVER ($IP)"
  echo "- Location -> $CITY, $COUNTRY"
  echo "- Load -> $LOAD  (low is better)"

  echo "[Interface]
PrivateKey = $MY_KEY
Address = 10.5.0.2/32

[Peer]
PublicKey = $NORD_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $IP:51820
PersistentKeepalive = 25" > $OUT_CONFIG_FILE

  echo "*** wrote config file: $OUT_CONFIG_FILE"

  # clean-up
  rm -f $TMP

fi

# EOF
