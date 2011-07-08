#!/bin/bash
#
# gnarwall-setup.sh
#
# Configures GnarWall.  Can be run on system startup or manually.

# Configuration variables
host=firewall
domain=mydept.example.com
timezone='America/Los_Angeles'
locale='en_US.UTF-8'
email='admin@example.com'
timeserver=time.example.com
nameserver1=192.168.0.221
nameserver2=192.168.0.222
dns_search_order="$domain example.com"
dis_ipv6=0             # 1=True (to disable ipv6) or 0=False (don't)
bell='none'            # Set to 'none', 'visible', or '' for audible

gnarwall=/etc/gnarwall
gnarwall_conf=$gnarwall/configured

# Create /etc/resolv.conf if it does not already exist
resolv_conf=/etc/resolv.conf

[ -s $resolv_conf ] || cat > $resolv_conf <<EOF
search $dns_search_order
nameserver $nameserver1
nameserver $nameserver2
EOF

# Set time from campus time server
rdate -s $timeserver

# Skip the rest of this script if the system has already been configured
[ -e $gnarwall_conf ] && exit 0

# Create an /etc/ntp.conf if one does not already exist
ntp_conf=/etc/ntp.conf

([ -s $ntp_conf ] && grep -q $timeserver $ntp_conf) || cat > $ntp_conf <<EOF
disable stats
driftfile /var/lib/ntp/drift
broadcastdelay  0.008
server $timeserver
EOF

# Reconfigure timezone
reconfigure=/usr/sbin/dpkg-reconfigure
timezone_conf=/etc/timezone
timezone_package=tzdata
echo "$timezone" > $timezone_conf
$reconfigure -f noninteractive  $timezone_package 2>/dev/null

# Set mailname and hostname if they have not been already configured
fqdn=${host}.${domain}
mn_conf=/etc/mailname
hn_conf=/etc/hostname
hostname_bin=/bin/hostname
$hostname_bin | grep -q ${host} || $hostname_bin ${host}
([ -s $hn_conf ] && grep -q $fqdn $hn_conf) || echo $fqdn > $hn_conf
([ -s $mn_conf ] && grep -q $fqdn $mn_conf) || echo $fqdn > $mn_conf

# Create /etc/hosts if it does not already exist
hosts_conf=/etc/hosts

[ -s $hosts_conf ] || cat > $hosts_conf <<EOF
127.0.0.1 localhost
127.0.1.1 $fqdn ${hostname}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

# Set locale environmental variables
export LANGUAGE="$locale"
export LANG="$locale"
export LC_ALL="$locale"

# Create /etc/default/locale if it does not already contain my locale 
loc=/etc/default/locale
([ -s $loc ] && grep -q "^LANG=$LANG" $loc) || echo LANG=$LANG > $loc

# Create /etc/locale.gen if it does not already contain my locale 
loc_gen_conf=/etc/locale.gen
loc_gen_bin=/usr/sbin/locale-gen
reconfigure=/usr/sbin/dpkg-reconfigure
[ -s $loc_gen_conf ] && grep -q "^$LANG" $loc_gen_conf
if [ $? != 0 ]; then \
   /usr/bin/dpkg-query -W -f='${Status} ${Version}\n' locales > /dev/null
   if [ $? = 0 ]; then \
      rm -f $loc_gen_conf
      $loc_gen_bin "$LANG"
      $reconfigure -u locales
   fi
fi

# Set bell-style in /etc/initrc
inputrc=/etc/inputrc
bell_style_cmd='set bell-style'

if [ -w $inputrc ]; then \
   if [ -z "$bell" ]; then \
      # Comment out all "set bell style" lines to enable default bell
      sed -i "s/^$bell_style_cmd/# $bell_style_cmd/g" $inputrc
   else \
      # Remove all "set bell style" lines and append new one
      sed -i -n "/$bell_style_cmd/!p" $inputrc
      echo "$bell_style_cmd $bell" >> $inputrc
   fi
else
   echo "Can't write to $inputrc!  Can't change bell-style!"
fi

# Modify logcheck ignore rules for ntpd to ignore "time sync status change"
# See:  http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=498992
# This is fixed in logcheck version 1:4.2.6+dfsg-1 on Sat, 26 Dec 2009
lcntp=/etc/logcheck/ignore.d.server/ntp
lcn1='kernel time sync (disabled|enabled)'
lcn2='kernel time sync (enabled|status( change)?)'
([ -s $lcntp ] && grep -qF "$lcn1" $lcntp) && sed -i "s/$lcn1/$lcn2/" $lcntp

# Configure adminstrative email address for logwatch, postmaster, and root.
lc_conf=/etc/logcheck/logcheck.conf
aliases=/etc/aliases
newaliases=/usr/bin/newaliases
[ -s $lc_conf ] && sed -i "s/^\(SENDMAILTO\)=.*$/\1='$email'/" $lc_conf
sed -i "s/^\(postmaster\|logcheck\|root\):.*$/\1:\t$email/" $aliases
[ -x $newaliases ] && $newaliases

# Set defaults for snmpd to log only up to info level
snmpd_conf=/etc/default/snmpd
cat > $snmpd_conf <<EOF
export MIBS=
SNMPDRUN=yes
SNMPDOPTS='-LS6d -Lf /dev/null -u snmp -g snmp -I -smux -p /var/run/snmpd.pid'
TRAPDRUN=no
TRAPDOPTS='-LS6d -p /var/run/snmptrapd.pid'
SNMPDCOMPAT=yes
EOF

# Set default for rcS to run only one script at a time
rcs_conf=/etc/default/rcS
[ -s $rcs_conf ] && grep -q "^CONCURRENCY=" $rcs_conf
if [ $? != 0 ]; then \
   echo 'CONCURRENCY=none' >> $rcs_conf
else
   grep -q "^CONCURRENCY=none" $rcs_conf
   if [ $? != 0 ]; then \
      sed -i "s/^\(CONCURRENCY\)=.*$/\1=none/" $rcs_conf
   fi
fi

# Disable IPv6
# See: http://www.debian-administration.org/article/409/
dis_ipv6_conf=/etc/network/if-pre-up.d/dis_ipv6
chmod=/bin/chmod
[ "$dis_ipv6" == "1" ] && ([ -s $dis_ipv6_conf ] || cat > $dis_ipv6_conf <<EOF
#!/bin/sh

/sbin/sysctl -w net.ipv6.conf.all.dis_ipv6=1
EOF
([ -w $dis_ipv6_conf ] && [ -x $chmod ]) && $chmod 750 $dis_ipv6_conf)

# Leave a trace that this script has run at least once to completion
mkdir -p $gnarwall
touch $gnarwall_conf

exit 0
