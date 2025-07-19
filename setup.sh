#!/usr/bin/env bash
# UltraPBR Toolkit — یک اسکریپت تعاملی برای تنظیم PBR روی OpenWrt

# === نمایش بنر UltraPBR ===
function show_banner() {
    clear
    echo -e "\e[1;34m"
    echo "============================================"
    echo "      🛡️  UltraPBR Toolkit  🛡️"
    echo "============================================"
    echo -e "\e[0m"
}

# === بررسی دسترسی روت ===
function check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "⚠️ لطفاً این اسکریپت را به‌صورت root اجرا کنید."
        exit 1
    fi
}

# === نصب بسته‌ها ===
function install_packages() {
    echo "⏳ بروزرسانی مخازن و نصب بسته‌های مورد نیاز..."
    opkg update || { echo "خطا در بروزرسانی مخازن!"; exit 1; }
    for pkg in pbr wireless-tools; do
        opkg install "$pkg" || { echo "نصب $pkg با خطا مواجه شد."; exit 1; }
    done
    echo "✅ بسته‌ها با موفقیت نصب شدند."
}

# === لیست اینترفیس‌ها و انتخاب WAN1 ===
function select_wan1() {
    echo
    echo "📡 اینترفیس‌های فعال:"
    ip -o link show | awk -F': ' '{print NR": "$2}'
    echo
    read -rp "عدد اینترفیس برای WAN1 (اینترنت بین‌الملل) را وارد کنید: " idx
    WAN1_IF=$(ip -o link show | awk -F': ' '{print $2}' | sed -n "${idx}p")
    echo "اینترفیس انتخاب‌شده برای WAN1: $WAN1_IF"
}

# === اسکن و اتصال WiFi ===
function scan_wifi() {
    local iface=$1
    echo
    echo "در حال اسکن شبکه‌های 2.4GHz روی اینترفیس $iface..."
    wifi detect > /dev/null 2>&1
    iwlist "$iface" scanning | grep -E 'Cell |ESSID' | nl -w2 -s'. ' | awk '{$1=""; print}'
    echo
    read -rp "شماره WiFi مدنظر را وارد کنید: " wnum
    SSID=$(iwlist "$iface" scanning | grep -E 'ESSID' | sed -n "${wnum}q;d" | cut -d'"' -f2)
    read -rsp "رمز WiFi '$SSID' را وارد کنید: " PSK
    echo
    echo "در حال پیکربندی WiFi..."
    uci delete wireless.@wifi-iface[0] 2>/dev/null || true
    uci set wireless.@wifi-iface[0]=wifi-iface
    uci set wireless.@wifi-iface[0].device='radio0'
    uci set wireless.@wifi-iface[0].network="$2"
    uci set wireless.@wifi-iface[0].mode='sta'
    uci set wireless.@wifi-iface[0].ssid="$SSID"
    uci set wireless.@wifi-iface[0].encryption='psk2'
    uci set wireless.@wifi-iface[0].key="$PSK"
    uci commit wireless
    wifi reload
    echo "✅ WiFi متصل و پیکربندی شد."
}

# === تنظیم WAN1 ===
function configure_wan1() {
    echo
    echo "آیا می‌خواهید اینترنت بین‌الملل (WAN1) از طریق WiFi باشد؟ [y/N]"
    read -rn1 use_wifi; echo
    if [[ "$use_wifi" =~ ^[Yy]$ ]]; then
        scan_wifi "$WAN1_IF" "wan"
    else
        echo "WAN1 روی اینترفیس $WAN1_IF تنظیم شد."
    fi
}

# === تنظیم WAN2 (Iran Internet) ===
function configure_wan2() {
    echo
    echo "🌐 تنظیم اینترنت ایران (WAN2/WWAN)"
    echo "آیا می‌خواهید از اینترفیس موجود استفاده کنید یا WiFi؟"
    select opt in "اینترفیس موجود" "WiFi"; do
        case $REPLY in
            1)
                echo "اینترفیس موجود انتخاب شد."
                read -rp "نام اینترفیس WAN2 را وارد کنید: " WAN2_IF
                break
                ;;
            2)
                echo "انتخاب WiFi برای WAN2"
                # فرض شده radio0 دوباره
                scan_wifi "radio0" "wan2"
                WAN2_IF="wan2"
                break
                ;;
            *)
                echo "لطفاً عدد 1 یا 2 را وارد کنید."
                ;;
        esac
    done
    echo "اینترفیس WAN2: $WAN2_IF"
}

# === اعمال سیاست‌های PBR ===
function apply_pbr() {
    echo
    echo "🔧 اعمال تنظیمات PBR..."
    # فعال‌سازی PBR
    uci set pbr.@global[0].enabled='1'
    uci set pbr.@global[0].strict='1'
    uci set pbr.@global[0].interfaces="$WAN1_IF $WAN2_IF"
    uci commit pbr

    # دانلود لیست‌های ایران
    echo "⏳ دانلود لیست IP ایران..."
    wget -qO /etc/pbr/iran_ip_list.txt https://raw.githubusercontent.com/UltraPBR/Lists/main/iran_ip_list.txt || true
    echo "⏳ دانلود لیست دامنه‌های ایران..."
    wget -qO /etc/pbr/iran_domain_list.txt https://raw.githubusercontent.com/UltraPBR/Lists/main/iran_domain_list.txt || true

    # تعریف سیاست‌ها
    pbr route add name IranRoutes ips /etc/pbr/iran_ip_list.txt gateway $WAN2_IF priority 10
    pbr route add name IranDomains domains /etc/pbr/iran_domain_list.txt gateway $WAN2_IF priority 20
    pbr route add name DefaultAll gateway $WAN1_IF priority 100

    echo "✅ سیاست‌های PBR تنظیم شدند."
}

# === تغییر IP LAN ===
function set_lan_ip() {
    echo
    echo "🔄 تغییر IP LAN به 192.168.200.1/24"
    uci set network.lan.ipaddr='192.168.200.1'
    uci set network.lan.netmask='255.255.255.0'
    uci commit network
}

# === تغییر هدر LuCI ===
function rebrand_luci() {
    echo
    echo "🎨 تغییر هدر LuCI به 'by-UltraPBR'"
    UCI_PATH="/usr/lib/lua/luci/view/themes/bootstrap/header.htm"
    if [ -f "$UCI_PATH" ]; then
        sed -i "s/OpenWrt/by-UltraPBR/g" "$UCI_PATH"
    fi
}

# === ری‌استارت سرویس‌ها ===
function restart_services() {
    echo
    echo "♻️ راه‌اندازی مجدد سرویس‌ها..."
    /etc/init.d/network restart
    /etc/init.d/uhttpd restart
    /etc/init.d/pbr restart
}

# === اجرای مراحل ===
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

echo -e "\n✅ تنظیمات UltraPBR با موفقیت انجام شد! خداحافظ از UltraPBR 👋🚀"
