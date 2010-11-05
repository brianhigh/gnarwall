#!/bin/sh
#
# gnarwall-setup.sh

MY_HOSTNAME=firewall
MY_DOMAINNAME=mydept.example.com
MY_TIMEZONE='America/Los_Angeles'
MY_LOCALE='LANG=en_US.UTF-8'
MY_EMAIL='admin@example.com'
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

if [ -w $EIR ]; then \
   if [ -z "$MY_BELL" ]; then \
      # Comment out all "set bell style" lines to enable default bell
      sed -i "s/^$SBS/# $SBS/g" $EIR
   else \
      # Remove all "set bell style" lines and append new one
      sed -i -n "/$SBS/!p" $EIR
      echo "$SBS $MY_BELL" >> $EIR
   fi
else
   echo "Can't write to $EIR!  Can't change bell-style!"
fi

# Modify logcheck ignore rules for ntpd to ignore "time sync status change"
# See:  http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=498992
# This is fixed in logcheck version 1:4.2.6+dfsg-1 (26 Dec 2009).
BCM=/bin/chmod
LCN=/etc/logcheck/ignore.d.server/ntp
LCN1='kernel time sync (disabled|enabled)'
LCN2='kernel time sync (enabled|status( change)?)'
([ -w $LCN ] && grep -qF "$LCN1" $LCN) && sed -i "s/$LCN1/$LCN2/" $LCN
([ -w $LCN ] && [ -x $BCM ]) && $BCM 640 $LCN

# Also, ignore rsyslogd restarts.  Fixed in rsyslog 3.20.5-1 (08 Apr 2009).
# See:  http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=522164
BCM=/bin/chmod
LCR=/etc/logcheck/ignore.d.server/rsyslog
[ -s $LCR ] || cat > $LCR <<EOF
^\w{3} [ :0-9]{11} [._[:alnum:]-]+ kernel:( \[[[:digit:]]+\.[[:digit:]]+\])? imklog [0-9.]+, log source = /proc/kmsg started.$
^\w{3} [ :0-9]{11} [._[:alnum:]-]+ rsyslogd: \[origin software="rsyslogd" swVersion="[0-9.]+" x-pid="[0-9]+" x-info="http://www.rsyslog.com"\] restart$
EOF
([ -w $LCR ] && [ -x $BCM ]) && $BCM 640 $LCR

# Configure adminstrative email address for logwatch, postmaster, and root.
LCC=/etc/logcheck/logcheck.conf
EA=/etc/aliases
UBN=/usr/bin/newaliases
[ -s $LCC ] && sed -i "s/^\(SENDMAILTO\)=.*$/\1='$MY_EMAIL'/" $LCC
sed -i "s/^\(postmaster\|logcheck\|root\):.*$/\1:\t$MY_EMAIL/" $EA
[ -x $UBN ] && $UBN

# Leave a trace that this script has run at least once to completion
mkdir -p $MY_GNARWALL
touch $MY_CONFIGURED

exit 0
