#!/bin/sh
#
# gnarwall-setup.sh

MY_HOSTNAME=firewall
MY_DOMAINNAME=mydept.example.com
MY_TIMEZONE='America/Los_Angeles'
MY_LOCALE='LANG=en_US.UTF-8'
MY_TIMESERVER=time.example.com
MY_NAMESERVER1=192.168.0.221
MY_NAMESERVER2=192.168.0.222
MY_DNSSEARCH="$MY_DOMAINNAME example.com"
MY_BELL='none'            # Set to 'none', 'visible', or '' for audible

MY_GNARWALL=/etc/gnarwall
MY_CONFIGURED=$MY_GNARWALL/configured

# Create /etc/resolv.conf if it does not already exist
ERC=/etc/resolv.conf

[ -s $ERC ] || cat > $ERC <<EOF
search $MY_DNSSEARCH
nameserver $MY_NAMESERVER1
nameserver $MY_NAMESERVER2
EOF

# Set time from campus time server
rdate -s $MY_TIMESERVER

# Skip the rest of this script if the system has already been configured
[ -e $MY_CONFIGURED ] && exit 0

# Create an /etc/ntp.conf if one does not already exist
ENC=/etc/ntp.conf

([ -s $ENC ] && grep -q $MY_TIMESERVER) || cat > $ENC <<EOF
disable stats
driftfile /var/lib/ntp/drift
broadcastdelay  0.008
server $MY_TIMESERVER
EOF

# Reconfigure timezone
UBR=/usr/sbin/dpkg-reconfigure
ETZ=/etc/timezone
PKG=tzdata
echo "$MY_TIMEZONE" > $ETZ
$UBR -f noninteractive  $PKG 2>/dev/null

# Set mailname and hostname if they have not been already configured
FQDN=${MY_HOSTNAME}.${MY_DOMAINNAME}
EMN=/etc/mailname
EHN=/etc/hostname
BHN=/bin/hostname
$BHN | grep -q ${MY_HOSTNAME} || $BHN ${MY_HOSTNAME}
([ -s $EHN ] && grep -q $FQDN $EHN) || echo $FQDN > $EHN
([ -s $EMN ] && grep -q $FQDN $EMN) || echo $FQDN > $EMN

# Create /etc/hosts if it does not already exist
EH=/etc/hosts

[ -s $EH ] || cat > $EH <<EOF
127.0.0.1 localhost
127.0.1.1 $FQDN ${MY_HOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

# Create /etc/default/locale if it does not already contain my locale 
EDL=/etc/default/locale
([ -s $EDL ] && grep -q $MY_LOCALE $EDL) || echo $MY_LOCALE > $EDL

# Set bell-style in /etc/initrc
EIR=/etc/inputrc
SBS='set bell-style'
PERL=/usr/bin/perl

if [ -x $PERL -a -w $EIR ]; then \
   if [ -z "$MY_BELL" ]; then \
      # Comment out all "set bell style" lines to enable default bell
      $PERL -pi -e "s/^$SBS/# $SBS/g" $EIR
   else \
      # Remove all "set bell style" lines and append new one
      $PERL -ni -e "print unless /$SBS/" $EIR
      grep -q "^$SBS $MY_BELL" $EIR || echo "$SBS $MY_BELL" >> $EIR
   fi
else
   echo "Can't execute $PERL or write to $EIR!  Won't change bell-style!"
fi

# Leave a trace that this script has run at least once to completion
mkdir -p $MY_GNARWALL
touch $MY_CONFIGURED

exit 0
