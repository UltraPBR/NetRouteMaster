#!/bin/sh
# UltraPBR Toolkit — Interactive script to configure PBR on OpenWrt

# === Display UltraPBR Banner ===
show_banner() {
    clear
    echo "\033[1;34m"
    echo "============================================"
    echo "      🛡️  UltraPBR Toolkit  🛡️"
    echo "============================================"
    echo "\033[0m"
}

# === Check for Root Privileges ===
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "⚠️ Please run this script as root."
        exit 1
    fi
}

# === Install Required Packages ===
install_packages() {
    echo "⏳ Waiting for any existing opkg lock to be released..."
    while [ -f /var/lock/opkg.lock ]; do
        echo "🔒 opkg is busy, waiting..."
        sleep 2
    done

    echo "⏳ Updating package lists..."
    opkg update || { echo "Error updating package lists!"; exit 1; }

    echo "⏳ Installing required packages..."
    for pkg in pbr wireless-tools; do
        while [ -f /var/lock/opkg.lock ]; do
            echo "🔒 opkg is busy, waiting..."
            sleep 2
        done
        opkg install "$pkg" || { echo "Failed to install $pkg."; exit 1; }
    done
    echo "✅ Packages installed successfully."
}

# === List Interfaces and Select WAN1 ===
select_wan1() {
    echo
    echo "📡 Active network interfaces:"
    ip -o link show | awk -F': ' '{print NR": "$2}'
    echo
    printf "Enter the number of the interface for WAN1 (International Internet): "
    read -r idx
    WAN1_IF=$(ip -o link show | awk -F': ' '{print $2}' | sed -n "${idx}p")
    echo "✅ WAN1 interface: $WAN1_IF"
}

# === Scan and Connect to WiFi ===
scan_wifi() {
    iface="$1"
    target_net="$2"
    echo
    echo "Scanning 2.4GHz WiFi networks on $iface..."
    wifi detect >/dev/null 2>&1 || true
    iwlist "$iface" scanning 2>/dev/null \
      | grep -E 'Cell |ESSID' \
      | nl -w2 -s'. ' \
      | awk '{$1=""; sub(/^ /,""); print}'
    echo
    printf "Enter WiFi number: "
    read -r wnum
    SSID=$(iwlist "$iface" scanning 2>/dev/null \
      | grep -E 'ESSID' \
      | sed -n "${wnum}p" \
      | cut -d'\"' -f2)
    printf "Enter password for '$SSID': "
    stty -echo; read -r PSK; stty echo; echo
    echo "⏳ Configuring WiFi connection..."
    uci delete wireless.@wifi-iface[0] 2>/dev/null || true
    uci set wireless.@wifi-iface[0]=wifi-iface
    uci set wireless.@wifi-iface[0].device='radio0'
    uci set wireless.@wifi-iface[0].network="$target_net"
    uci set wireless.@wifi-iface[0].mode='sta'
    uci set wireless.@wifi-iface[0].ssid="$SSID"
    uci set wireless.@wifi-iface[0].encryption='psk2'
    uci set wireless.@wifi-iface[0].key="$PSK"
    uci commit wireless
    wifi reload
    echo "✅ WiFi connected and configured."
}

# === Configure WAN1 ===
configure_wan1() {
    echo
    printf "Do you want WAN1 via WiFi? [y/N]: "
    read -r yn
    case "$yn" in
        [Yy]* ) scan_wifi "$WAN1_IF" "wan" ;;
        *     ) echo "✅ Using interface $WAN1_IF for WAN1." ;;
    esac
}

# === Configure WAN2 (Iran Internet) ===
configure_wan2() {
    echo
    echo "🌐 Configuring Iran Internet (WAN2/WWAN)"
    while true; do
        echo "1) Use existing interface"
        echo "2) Use WiFi"
        printf "Your choice [1-2]: "
        read -r c
        case "$c" in
            1* )
                printf "Enter the name of the WAN2 interface: "
                read -r WAN2_IF
                break
                ;;
            2* )
                scan_wifi "radio0" "wan2"
                WAN2_IF="wan2"
                break
                ;;
            *  )
                echo "❌ Please enter 1 or 2."
                ;;
        esac
    done
    echo "✅ WAN2 interface: $WAN2_IF"
}

# === Apply PBR Policies ===
apply_pbr() {
    echo
    echo "🔧 Applying PBR settings..."
    uci set pbr.@global[0].enabled='1'
    uci set pbr.@global[0].strict='1'
    uci set pbr.@global[0].interfaces="$WAN1_IF $WAN2_IF"
    uci commit pbr

    mkdir -p /etc/pbr
    echo "⏳ Downloading Iran IP list..."
    wget -qO /etc/pbr/iran_ip_list.txt https://raw.githubusercontent.com/UltraPBR/Lists/main/iran_ip_list.txt || true
    echo "⏳ Downloading Iran domain list..."
    wget -qO /etc/pbr/iran_domain_list.txt https://raw.githubusercontent.com/UltraPBR/Lists/main/iran_domain_list.txt || true

    pbr route add name IranRoutes ips /etc/pbr/iran_ip_list.txt gateway "$WAN2_IF" priority 10
    pbr route add name IranDomains domains /etc/pbr/iran_domain_list.txt gateway "$WAN2_IF" priority 20
    pbr route add name DefaultAll gateway "$WAN1_IF" priority 100
    echo "✅ PBR policies configured."
}

# === Set LAN IP ===
set_lan_ip() {
    echo
    echo "🔄 Changing LAN IP to 192.168.200.1/24"
    uci set network.lan.ipaddr='192.168.200.1'
    uci set network.lan.netmask='255.255.255.0'
    uci commit network
}

# === Rebrand LuCI Header ===
rebrand_luci() {
    echo
    echo "🎨 Changing LuCI header to 'by-UltraPBR'"
    H="/usr/lib/lua/luci/view/themes/bootstrap/header.htm"
    [ -f "$H" ] && sed -i "s/OpenWrt/by-UltraPBR/g" "$H"
}

# === Restart Services ===
restart_services() {
    echo
    echo "♻️ Restarting services..."
    /etc/init.d/network restart
    /etc/init.d/uhttpd restart
    /etc/init.d/pbr restart
}

# === Execute All Steps ===
show_banner
check_root
install_packages
select_wan1
configure_wan1
configure_wan2
apply_pbr
set_lan_ip
rebrand_luci
restart_services

echo
echo "✅ UltraPBR setup completed successfully! Goodbye from UltraPBR 👋🚀"
