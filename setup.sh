#!/bin/sh

clear

# Load banner
wget -q -O /tmp/banner.txt https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/banner.txt
if [ -f /tmp/banner.txt ]; then
    cat /tmp/banner.txt
else
    echo "#############################################################"
    echo "#                                                           #"
    echo "#                    UltraPBR Toolkit                       #"
    echo "#            Smart Policy-Based Routing Tool                #"
    echo "#                                                           #"
    echo "#                    by UltraPBR Team                       #"
    echo "#############################################################"
fi

echo "\nWelcome to UltraPBR Setup!\n"

# Install pbr package
echo "Installing pbr package..."
opkg update
opkg install pbr wireless-tools

echo "\nStep 1: Setup WAN1 (International Internet)"
printf "Enter WAN1 interface name (e.g., wan): "
read WAN1_INTERFACE

echo "\nStep 2: Setup Iran Network (WAN2 or WWAN)"
printf "Do you have a second WAN port? (y/n): "
read HAS_WAN2

if [ "$HAS_WAN2" = "y" ]; then
    printf "Enter WAN2 interface name: "
    read WAN2_INTERFACE
else
    echo "Scanning for available WiFi networks on 2.4GHz..."
    if command -v iwlist >/dev/null 2>&1; then
        iwlist wlan0 scan | grep 'ESSID' | nl
        printf "Select WiFi number to connect: "
        read WIFI_NUMBER
        printf "Enter WiFi Password: "
        read WIFI_PASS
        echo "(Simulated) Connecting to WiFi #$WIFI_NUMBER with provided password."
        WAN2_INTERFACE="wwan"
    else
        echo "iwlist not available! Skipping WiFi scan. Please install wireless-tools."
        WAN2_INTERFACE="wwan"
    fi
fi

echo "\nApplying PBR rules..."
uci set pbr.config.strict_enforcement='1'
uci set pbr.config.supported_interface="$WAN1_INTERFACE $WAN2_INTERFACE"
uci commit pbr
/etc/init.d/pbr restart

# Load Iran IPs and Domains
wget -q -O /etc/iran_domain_list https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/iran_domains.txt
wget -q -O /etc/iran_ip_list https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/iran_ips.txt

uci add pbr policy
uci set pbr.@policy[-1].name='Iran Routes'
uci set pbr.@policy[-1].interface="$WAN2_INTERFACE"
uci set pbr.@policy[-1].dest_addr='file:///etc/iran_ip_list'

uci add pbr policy
uci set pbr.@policy[-1].name='Iran Domains'
uci set pbr.@policy[-1].interface="$WAN2_INTERFACE"
uci set pbr.@policy[-1].dest_addr='file:///etc/iran_domain_list'

uci add pbr policy
uci set pbr.@policy[-1].name='Default via WAN'
uci set pbr.@policy[-1].interface="$WAN1_INTERFACE"
uci set pbr.@policy[-1].dest_addr='0.0.0.0/0'
uci commit pbr
/etc/init.d/pbr restart

# Change Router LAN IP
uci set network.lan.ipaddr='192.168.200.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

# Change LuCI header
uci set luci.main.mediaurlbase='/luci-static/bootstrap'
uci set luci.main.title='by-UltraPBR'
uci commit luci

# Restart services
/etc/init.d/network restart
/etc/init.d/uhttpd restart

echo "\n✅ UltraPBR setup completed successfully!"
echo "Enjoy seamless routing of Iran and International traffic!"
echo "Goodbye from UltraPBR 👋🚀"
