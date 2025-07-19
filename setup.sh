#!/bin/bash

clear
echo "##########################################"
echo "#                                        #"
echo "#           UltraPBR Toolkit             #"
echo "#    Smart Policy-Based Routing Tool     #"
echo "#                                        #"
echo "#            by UltraPBR Team            #"
echo "##########################################"

echo -e "\nWelcome to UltraPBR Setup!\n"
echo "Installing required packages..."
opkg update
opkg install pbr wireless-tools luci

# Step 1: Select WAN1
echo -e "\nAvailable network interfaces:"
ifconfig | grep flags | cut -d ':' -f1
echo ""
read -p "Enter the interface name for WAN1 (International Internet): " WAN1_INTERFACE

# Step 2: Setup Iran Network
echo ""
read -p "Do you want to configure Iran Internet on WAN2 or WiFi (wwan)? (wan2/wifi): " IRAN_NETWORK_CHOICE

if [[ $IRAN_NETWORK_CHOICE == "wan2" ]]; then
    read -p "Enter the interface name for WAN2: " WAN2_INTERFACE
elif [[ $IRAN_NETWORK_CHOICE == "wifi" ]]; then
    echo "Scanning for available 2.4GHz WiFi networks..."
    iwlist wlan0 scan | grep 'ESSID' | nl
    read -p "Select WiFi number to connect: " WIFI_NUMBER
    read -p "Enter WiFi Password: " WIFI_PASS
    echo "(Simulated) Connecting to WiFi #$WIFI_NUMBER with password."
    WAN2_INTERFACE="wwan"
else
    echo "Invalid choice, exiting."
    exit 1
fi

# Download Iran IPs and Domains
wget -q -O /etc/iran_ip_list https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/iran_ips.txt
wget -q -O /etc/iran_domain_list https://raw.githubusercontent.com/UltraPBR/NetRouteMaster/main/iran_domains.txt

echo -e "\nApplying PBR policies..."
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
uci set pbr.@policy[-1].name='Default via WAN1'
uci set pbr.@policy[-1].interface="$WAN1_INTERFACE"
uci set pbr.@policy[-1].dest_addr='0.0.0.0/0'

uci commit pbr
/etc/init.d/pbr restart

echo -e "\nChanging router LAN IP to 192.168.200.1/24..."
uci set network.lan.ipaddr='192.168.200.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

echo "Customizing LuCI WebUI header..."
uci set luci.main.title='by-UltraPBR'
uci commit luci

/etc/init.d/network restart
/etc/init.d/uhttpd restart

echo -e "\n✅ UltraPBR setup completed successfully!"
echo "Goodbye from UltraPBR 👋🚀"
