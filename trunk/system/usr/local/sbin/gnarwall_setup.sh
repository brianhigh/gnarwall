#!/bin/bash
#
# gnarwall-setup.sh

MY_HOSTNAME=firewall
MY_DOMAINNAME=mydept.example.com
MY_TIMEZONE='America/Los_Angeles'
MY_LOCALE='en_US.UTF-8'
MY_EMAIL='admin@example.com'
MY_TIMESERVER=time.example.com
MY_NAMESERVER1=192.168.0.221
MY_NAMESERVER2=192.168.0.222
MY_DNSSEARCH="$MY_DOMAINNAME example.com"
MY_DISABLE_IPV6=0         # 1=True (to disable ipv6) or 0=False (don't)
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

([ -s $ENC ] && grep -q $MY_TIMESERVER $ENC) || cat > $ENC <<EOF
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

# Set locale environmental variables
export LANGUAGE="$MY_LOCALE"
export LANG="$MY_LOCALE"
export LC_ALL="$MY_LOCALE"

# Create /etc/default/locale if it does not already contain my locale 
EDL=/etc/default/locale
([ -s $EDL ] && grep -q "^LANG=$LANG" $EDL) || echo LANG=$LANG > $EDL

# Create /etc/locale.gen if it does not already contain my locale 
ELG=/etc/locale.gen
[ -s $ELG ] && grep -q "^$LANG" $ELG
if [ $? != 0 ]; then \
   /usr/bin/dpkg-query -W -f='${Status} ${Version}\n' locales > /dev/null
   if [ $? = 0 ]; then \
      rm -f $ELG
      /usr/sbin/locale-gen "$LANG"
      /usr/sbin/dpkg-reconfigure -u locales
   fi
fi

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
# This is fixed in logcheck version 1:4.2.6+dfsg-1 on Sat, 26 Dec 2009
LCN=/etc/logcheck/ignore.d.server/ntp
LCR1='kernel time sync (disabled|enabled)'
LCR2='kernel time sync (enabled|status( change)?)'
([ -s $LCN ] && grep -qF "$LCR1" $LCN) && sed -i "s/$LCR1/$LCR2/" $LCN

# Configure adminstrative email address for logwatch, postmaster, and root.
LCC=/etc/logcheck/logcheck.conf
EA=/etc/aliases
UBN=/usr/bin/newaliases
[ -s $LCC ] && sed -i "s/^\(SENDMAILTO\)=.*$/\1='$MY_EMAIL'/" $LCC
sed -i "s/^\(postmaster\|logcheck\|root\):.*$/\1:\t$MY_EMAIL/" $EA
[ -x $UBN ] && $UBN

# Set defaults for snmpd to log only up to info level
EDS=/etc/default/snmpd
cat > $EDS <<EOF
export MIBS=
SNMPDRUN=yes
SNMPDOPTS='-LS6d -Lf /dev/null -u snmp -g snmp -I -smux -p /var/run/snmpd.pid'
TRAPDRUN=no
TRAPDOPTS='-LS6d -p /var/run/snmptrapd.pid'
SNMPDCOMPAT=yes
EOF

# Set default for rcS to run only one script at a time
EDR=/etc/default/rcS
[ -s $EDR ] && grep -q "^CONCURRENCY=" $EDR
if [ $? != 0 ]; then \
   echo 'CONCURRENCY=none' >> $EDR
else
   grep -q "^CONCURRENCY=none" $EDR
   if [ $? != 0 ]; then \
      sed -i "s/^\(CONCURRENCY\)=.*$/\1=none/" $EDR
   fi
fi

# Disable IPv6
# See: http://www.debian-administration.org/article/409/
DV6=/etc/network/if-pre-up.d/disable_ipv6
BCM=/bin/chmod
[ "$MY_DISABLE_IPV6" == "1" ] && ([ -s $DV6 ] || cat > $DV6 <<EOF
#!/bin/sh

/sbin/sysctl -w net.ipv6.conf.all.disable_ipv6=1
EOF
([ -w $DV6 ] && [ -x $BCM ]) && $BCM 750 $DV6)

# Leave a trace that this script has run at least once to completion
mkdir -p $MY_GNARWALL
touch $MY_CONFIGURED

exit 0
