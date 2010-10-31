#!/bin/sh

# gnarwall-reset.sh
#
# Remove configuration files so they will be recreated later.

CONFFILE=/etc/gnarwall/configured

cd /etc && rm -f resolv.conf timezone hostname mailname hosts ntp.conf
[ -e $CONFFILE ] && rm -f $CONFFILE
