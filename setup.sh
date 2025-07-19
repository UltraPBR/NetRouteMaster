#!/bin/bash

clear

# Load banner
wget -q -O /tmp/banner.txt https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/banner.txt
if [ -f /tmp/banner.txt ]; then
    cat /tmp/banner.txt
else
    echo "##########################################"
    echo "#                                        #"
    echo "#           UltraPBR Toolkit             #"
    echo "#    Smart Policy-Based Routing Tool     #"
    echo "#                                        #"
    echo "#            by UltraPBR Team            #"
    echo "##########################################"
fi

echo -e "\nWelcome to UltraPBR Setup!\n"

# Install required packages
echo "Installing required packages..."
opkg update
opkg install pbr wireless-tools

# Setup WAN1
echo -e "\nStep 1: Setup WAN1 (International Internet)"
read -p "Enter WAN1 interface name (e.g., wan): " WAN1_INTERFACE

# Setup WAN2 or WWAN
echo -e "\nStep 2: Setup Iran Network (WAN2 or WWAN)"
read -p "Do you want to use a second WAN port? (y/n): " USE_WAN2

if [ "$USE_WAN2" == "y" ]; then
    read -p "Enter WAN2 interface name: " WAN2_INTERFACE
else
    echo "Scanning for available WiFi networks on 2.4GHz..."
    if command -v iwlist >/dev/null 2>&1; then
        iwlist wlan0 scan | grep 'ESSID' | nl
        read -p "Select WiFi number to connect: " WIFI_NUMBER
        read -p "Enter WiFi SSID: " WIFI_SSID
        read -p "Enter WiFi Password: " WIFI_PASS
        echo "Connecting to WiFi SSID '$WIFI_SSID'..."
        uci set wireless.@wifi-iface[0].mode='sta'
        uci set wireless.@wifi-iface[0].ssid="$WIFI_SSID"
        uci set wireless.@wifi-iface[0].encryption='psk2'
        uci set wireless.@wifi-iface[0].key="$WIFI_PASS"
        uci commit wireless
        wifi reload
        WAN2_INTERFACE="wwan"
    else
        echo "iwlist not available! Cannot scan WiFi networks."
        exit 1
    fi
fi

# Apply PBR Configuration
echo -e "\nApplying PBR rules..."
uci set pbr.config.strict_enforcement='1'
uci set pbr.config.supported_interface="$WAN1_INTERFACE $WAN2_INTERFACE"
uci commit pbr
/etc/init.d/pbr restart

# Download Iran IPs and Domains
wget -q -O /etc/iran_domain_list https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/iran_domains.txt
wget -q -O /etc/iran_ip_list https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/iran_ips.txt

# Configure PBR Policies
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

# Change LuCI Title
uci set luci.main.title='by-UltraPBR'
uci commit luci

# Restart services
/etc/init.d/network restart
/etc/init.d/uhttpd restart

echo -e "\n✅ UltraPBR setup completed successfully!"
echo "Enjoy seamless routing of Iran and International traffic!"
echo "Goodbye from UltraPBR 👋🚀"
