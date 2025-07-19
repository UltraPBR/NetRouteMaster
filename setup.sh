#!/bin/sh
# UltraPBR Toolkit — اسکریپت تعاملی برای تنظیم PBR روی OpenWrt

# === نمایش بنر UltraPBR ===
show_banner() {
    clear
    echo "\033[1;34m"
    echo "============================================"
    echo "      🛡️  UltraPBR Toolkit  🛡️"
    echo "============================================"
    echo "\033[0m"
}

# === بررسی دسترسی روت ===
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "⚠️ لطفاً این اسکریپت را به‌صورت root اجرا کنید."
        exit 1
    fi
}

# === نصب بسته‌ها ===
install_packages() {
    echo "⏳ بروزرسانی مخازن و نصب بسته‌های مورد نیاز..."
    opkg update || { echo "خطا در بروزرسانی مخازن!"; exit 1; }
    for pkg in pbr wireless-tools; do
        opkg install "$pkg" || { echo "نصب $pkg با خطا مواجه شد."; exit 1; }
    done
    echo "✅ بسته‌ها با موفقیت نصب شدند."
}

# === لیست اینترفیس‌ها و انتخاب WAN1 ===
select_wan1() {
    echo
    echo "📡 اینترفیس‌های فعال:"
    ip -o link show | awk -F': ' '{print NR": "$2}'
    echo
    printf "عدد اینترفیس برای WAN1 (اینترنت بین‌الملل) را وارد کنید: "
    read idx
    WAN1_IF=$(ip -o link show | awk -F': ' '{print $2}' | sed -n "${idx}p")
    echo "اینترفیس انتخاب‌شده برای WAN1: $WAN1_IF"
}

# === اسکن و اتصال WiFi ===
scan_wifi() {
    iface="$1"
    target_net="$2"
    echo
    echo "در حال اسکن شبکه‌های 2.4GHz روی اینترفیس $iface..."
    wifi detect >/dev/null 2>&1 || true
    iwlist "$iface" scanning 2>/dev/null | grep -E 'Cell |ESSID' | nl -w2 -s'. ' | awk '{$1=""; sub(/^ /,""); print}'
    echo
    printf "شماره WiFi مدنظر را وارد کنید: "
    read wnum
    SSID=$(iwlist "$iface" scanning 2>/dev/null | grep -E 'ESSID' | sed -n "${wnum}p" | cut -d'"' -f2)
    printf "رمز WiFi '$SSID' را وارد کنید: "
    stty -echo
    read PSK
    stty echo
    echo
    echo "⏳ در حال پیکربندی WiFi..."
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
    echo "✅ WiFi متصل و پیکربندی شد."
}

# === تنظیم WAN1 ===
configure_wan1() {
    echo
    printf "آیا می‌خواهید اینترنت بین‌الملل (WAN1) از طریق WiFi باشد؟ [y/N]: "
    read use_wifi
    case "$use_wifi" in
        [Yy]*)
            scan_wifi "$WAN1_IF" "wan"
            ;;
        *)
            echo "✅ WAN1 روی اینترفیس $WAN1_IF تنظیم شد."
            ;;
    esac
}

# === تنظیم WAN2 (Iran Internet) ===
configure_wan2() {
    echo
    echo "🌐 تنظیم اینترنت ایران (WAN2/WWAN)"
    while :; do
        echo "1) استفاده از اینترفیس موجود"
        echo "2) اتصال از طریق WiFi"
        printf "عدد گزینه را وارد کنید [1-2]: "
        read choice
        case "$choice" in
            1)
                printf "نام اینترفیس WAN2 را وارد کنید: "
                read WAN2_IF
                break
                ;;
            2)
                scan_wifi "radio0" "wan2"
                WAN2_IF="wan2"
                break
                ;;
            *)
                echo "❌ لطفاً عدد 1 یا 2 را وارد کنید."
                ;;
        esac
    done
    echo "✅ اینترفیس WAN2: $WAN2_IF"
}

# === اعمال سیاست‌های PBR ===
apply_pbr() {
    echo
    echo "🔧 اعمال تنظیمات PBR..."
    uci set pbr.@global[0].enabled='1'
    uci set pbr.@global[0].strict='1'
    uci set pbr.@global[0].interfaces="$WAN1_IF $WAN2_IF"
    uci commit pbr

    echo "⏳ دانلود لیست IP ایران..."
    mkdir -p /etc/pbr
    wget -qO /etc/pbr/iran_ip_list.txt https://raw.githubusercontent.com/UltraPBR/Lists/main/iran_ip_list.txt || true

    echo "⏳ دانلود لیست دامنه‌های ایران..."
    wget -qO /etc/pbr/iran_domain_list.txt https://raw.githubusercontent.com/UltraPBR/Lists/main/iran_domain_list.txt || true

    # سیاست‌ها
    pbr route add name IranRoutes ips /etc/pbr/iran_ip_list.txt gateway "$WAN2_IF" priority 10
    pbr route add name IranDomains domains /etc/pbr/iran_domain_list.txt gateway "$WAN2_IF" priority 20
    pbr route add name DefaultAll gateway "$WAN1_IF" priority 100

    echo "✅ سیاست‌های PBR با موفقیت تنظیم شدند."
}

# === تغییر IP LAN ===
set_lan_ip() {
    echo
    echo "🔄 تغییر IP LAN به 192.168.200.1/24"
    uci set network.lan.ipaddr='192.168.200.1'
    uci set network.lan.netmask='255.255.255.0'
    uci commit network
}

# === ری‌برندینگ LuCI ===
rebrand_luci() {
    echo
    echo "🎨 تغییر هدر LuCI به 'by-UltraPBR'"
    HEADER="/usr/lib/lua/luci/view/themes/bootstrap/header.htm"
    if [ -f "$HEADER" ]; then
        sed -i "s/OpenWrt/by-UltraPBR/g" "$HEADER"
    fi
}

# === ری‌استارت سرویس‌ها ===
restart_services() {
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

echo
echo "✅ UltraPBR setup completed successfully! خداحافظ از UltraPBR 👋🚀"
