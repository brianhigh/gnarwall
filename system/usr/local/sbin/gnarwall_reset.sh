#!/bin/sh

# gnarwall-reset.sh
#
# Remove configuration files so they will be recreated by
# gnarwall_setup.sh

# List of filenames
conf_files=(
'/etc/resolv.conf'
'/etc/timezone'
'/etc/hostname'
'/etc/mailname'
'/etc/hosts'
'/etc/ntp.conf'
'/etc/default/locale'
'/etc/locale.gen'
'/etc/network/if-pre-up.d/disable_ipv6'
'/etc/gnarwall/configured'
)

rm -f "${conf_files[@]}" 2>/dev/null
