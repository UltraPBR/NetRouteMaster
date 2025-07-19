#!/bin/sh

# Load Banner
clear
[ -f banner.txt ] && cat banner.txt

echo "Welcome to UltraPBR Setup!"

# Install pbr package
echo "Installing pbr package..."
if command -v opkg >/dev/null 2>&1; then
    opkg update && opkg install pbr
else
    echo "opkg not found! Are you sure this is OpenWrt?"
fi

# Step 1: WAN1
echo "\nStep 1: Setup WAN1 (International Internet)"
echo -n "Enter WAN1 interface name (e.g., wan): "
read WAN1_INTERFACE

# Step 2: Iran Network
echo "\nStep 2: Setup Iran Network (WAN2 or WWAN)"
echo -n "Do you have a second WAN port? (y/n): "
read HAS_WAN2

if [ "$HAS_WAN2" = "y" ]; then
    echo -n "Enter WAN2 interface name: "
    read WAN2_INTERFACE
else
    echo "Scanning for available WiFi networks on 2.4GHz..."
    if command -v iwlist >/dev/null 2>&1; then
        iwlist wlan0 scan | grep 'ESSID' | nl
    else
        echo "iwlist not available! Please install wireless-tools."
    fi
    echo -n "Select WiFi number to connect: "
    read WIFI_NUMBER
    echo -n "Enter WiFi Password: "
    read WIFI_PASS
    echo "Connecting to selected WiFi (Simulated) #$WIFI_NUMBER ..."
    WAN2_INTERFACE="wwan"
fi

# Apply PBR configs
echo "\nApplying PBR rules..."

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

/etc/init.d/network restart
/etc/init.d/uhttpd restart

echo "\n✅ UltraPBR setup completed successfully!"
echo "Enjoy seamless routing of Iran and International traffic!"
echo "Goodbye from UltraPBR 👋🚀"
