#!/bin/bash

# Load Banner
clear
cat banner.txt

echo "Welcome to UltraPBR Setup!"

# Install pbr package
echo "Installing pbr package..."
opkg update && opkg install pbr

# Configure International Internet on WAN1
echo -e "\nStep 1: Setup WAN1 (International Internet)"
read -p "Enter WAN1 interface name (e.g., wan): " WAN1_INTERFACE

# Configure Iran Network on WAN2 or WWAN
echo -e "\nStep 2: Setup Iran Network (WAN2 or WWAN)"
read -p "Do you have a second WAN port? (y/n): " HAS_WAN2

if [[ $HAS_WAN2 == "y" ]]; then
    read -p "Enter WAN2 interface name: " WAN2_INTERFACE
else
    echo "Scanning for available WiFi networks on 2.4GHz..."
    iwlist wlan0 scan | grep 'ESSID' | nl
    read -p "Select WiFi number to connect: " WIFI_NUMBER
    read -p "Enter WiFi Password: " WIFI_PASS
    echo "Connecting to selected WiFi as WWAN..."
    # Mock connection command here for user guidance
    echo "(Simulated) Connecting to WiFi #$WIFI_NUMBER with provided password."
    WAN2_INTERFACE="wwan"
fi

# Apply PBR rules
echo -e "\nApplying PBR rules..."
uci set pbr.config.strict_enforcement='1'
uci set pbr.config.supported_interface="$WAN1_INTERFACE $WAN2_INTERFACE"
uci commit pbr
/etc/init.d/pbr restart

# Load IPs and Domains
cp iran_domains.txt /etc/iran_domain_list
cp iran_ips.txt /etc/iran_ip_list

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

echo -e "\n✅ UltraPBR setup completed successfully!"
echo "Enjoy seamless routing of Iran and International traffic!"
echo "Goodbye from UltraPBR 👋🚀"
