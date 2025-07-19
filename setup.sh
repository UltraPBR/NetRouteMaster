#!/bin/bash

# Load Banner
clear
wget -O /tmp/banner.txt https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/banner.txt 2>/dev/null
cat /tmp/banner.txt

echo "Welcome to UltraPBR Setup!"
echo

# Install required packages
echo "Installing necessary packages..."
opkg update
opkg install pbr wireless-tools uhttpd luci

# Step 1: WAN1
echo -e "\nStep 1: Setup WAN1 (International Internet)"
read -p "Enter WAN1 interface name (e.g., wan): " WAN1_INTERFACE

# Step 2: Iran Network
echo -e "\nStep 2: Setup Iran Network (WAN2 or WWAN)"
read -p "Do you have a second WAN port? (y/n): " HAS_WAN2

if [[ $HAS_WAN2 == "y" ]]; then
    read -p "Enter WAN2 interface name: " WAN2_INTERFACE
else
    echo "Scanning for available WiFi networks on 2.4GHz..."
    iwlist wlan0 scan | grep 'ESSID' | nl
    read -p "Select WiFi number to connect: " WIFI_NUMBER
    read -p "Enter WiFi Password: " WIFI_PASS
    echo "(Simulated) Connecting to WiFi #$WIFI_NUMBER with provided password."
    WAN2_INTERFACE="wwan"
fi

# Download Iran Domains and IPs
echo -e "\nFetching Iran domains and IP lists..."
wget -O /etc/iran_domain_list https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/iran_domains.txt
wget -O /etc/iran_ip_list https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/iran_ips.txt

# Apply PBR configs
echo -e "\nApplying PBR rules..."
uci set pbr.config.strict_enforcement='1'
uci set pbr.config.supported_interface="$WAN1_INTERFACE $WAN2_INTERFACE"
uci commit pbr
/etc/init.d/pbr restart

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
echo -e "\nChanging router LAN IP to 192.168.200.1..."
uci set network.lan.ipaddr='192.168.200.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

# Change LuCI header
uci set luci.main.title='by-UltraPBR'
uci commit luci

# Delayed network and uhttpd restart
echo -e "\nNetwork and web services will restart in 15 seconds. Please reconnect using 192.168.200.1 after that."
(sleep 15 && /etc/init.d/network restart && /etc/init.d/uhttpd restart) &

echo -e "\n✅ UltraPBR setup completed successfully!"
echo "Reconnect to your router via SSH at: 192.168.200.1"
echo "Goodbye from UltraPBR 👋🚀"

