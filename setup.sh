#!/bin/sh

clear

# Banner
echo "##########################################"
echo "#                                        #"
echo "#           UltraPBR Toolkit             #"
echo "#    Smart Policy-Based Routing Tool     #"
echo "#                                        #"
echo "#            by UltraPBR Team            #"
echo "##########################################"
echo ""
echo "Welcome to UltraPBR Setup!"
echo ""

# Install dependencies
echo "Installing required packages..."
opkg update
opkg install pbr wireless-tools

echo ""
echo "Detecting active interfaces..."
ip link show | awk -F: '$0 !~ "lo|vir|br|docker|^[^0-9]"{print $2}' | nl
echo ""

echo -n "Enter the interface name for WAN1 (International Internet): "
read WAN1_INTERFACE

echo -n "Do you want to configure Iran Internet on WAN2 or WiFi (wwan)? (wan2/wifi): "
read IRAN_CHOICE

if [ "$IRAN_CHOICE" = "wan2" ]; then
    echo -n "Enter the interface name for WAN2: "
    read WAN2_INTERFACE
elif [ "$IRAN_CHOICE" = "wifi" ]; then
    echo "Scanning for available 2.4GHz WiFi networks..."
    iwlist wlan0 scan | grep 'ESSID' | nl
    echo -n "Enter WiFi number to connect: "
    read WIFI_NUMBER
    echo -n "Enter WiFi password: "
    read WIFI_PASS
    echo "(Simulated) Connecting to WiFi network $WIFI_NUMBER with password."
    WAN2_INTERFACE="wwan"
else
    echo "Invalid choice, exiting."
    exit 1
fi

echo ""
echo "Applying PBR rules..."
uci set pbr.config.strict_enforcement='1'
uci set pbr.config.supported_interface="$WAN1_INTERFACE $WAN2_INTERFACE"
uci commit pbr
/etc/init.d/pbr restart

echo ""
echo "Downloading Iran IP and domain lists..."
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

echo ""
echo "Changing LAN IP to 192.168.200.1/24..."
uci set network.lan.ipaddr='192.168.200.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

echo "Customizing LuCI branding..."
uci set luci.main.title='by-UltraPBR'
uci commit luci

echo "Restarting services..."
/etc/init.d/network restart
/etc/init.d/uhttpd restart

echo ""
echo "✅ UltraPBR setup completed successfully!"
echo "Goodbye from UltraPBR 👋🚀"
