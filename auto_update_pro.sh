#!/bin/bash

# ==============================================================
# 脚本名称: Auto Update & Reboot Manager (Pro Edition)
# 功能: 自动更新、支持任意时区/国家代码、自定义重启时间
# 系统: Debian / Ubuntu
# ==============================================================

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

# 任务配置文件路径
CRON_FILE="/etc/cron.d/custom_auto_update_reboot"

# 检查 Root 权限
check_root() {
    if [ $EUID -ne 0 ]; then
        echo -e "${RED}[错误] 请使用 sudo 或 root 权限运行此脚本！${PLAIN}"
        exit 1
    fi
}

# 检查系统兼容性
check_sys() {
    if [ ! -f /etc/debian_version ]; then
        echo -e "${RED}[警告] 本脚本仅支持 Debian/Ubuntu 系统！${PLAIN}"
        echo -e "检测到当前系统可能不兼容，是否继续? (y/n)"
        read -r choice
        if [[ "$choice" != "y" ]]; then
            exit 1
        fi
    fi
}

# 核心逻辑：获取并验证时区
get_valid_timezone() {
    while true; do
        echo -e "${CYAN}请输入时区设定:${PLAIN}"
        echo -e "  1. 支持国家代码缩写 (如: MY, TW, CN, HK, JP, SG, US, UK...)"
        echo -e "  2. 支持完整时区名称 (如: America/Los_Angeles)"
        read -p "请输入 (留空默认使用系统当前时区): " tz_input
        
        # 如果用户直接回车，使用当前系统时区
        if [ -z "$tz_input" ]; then
            TARGET_TZ=$(timedatectl show --property=Timezone --value)
            echo -e "${YELLOW}使用系统当前时区: $TARGET_TZ${PLAIN}"
            break
        fi

        # 将输入转换为大写以匹配缩写
        tz_upper=${tz_input^^}

        # 缩写映射表 (映射到该国首都或主要城市)
        case "$tz_upper" in
            MY) TARGET_TZ="Asia/Kuala_Lumpur" ;;
            TW) TARGET_TZ="Asia/Taipei" ;;
            CN) TARGET_TZ="Asia/Shanghai" ;;
            HK) TARGET_TZ="Asia/Hong_Kong" ;;
            SG) TARGET_TZ="Asia/Singapore" ;;
            JP) TARGET_TZ="Asia/Tokyo" ;;
            KR) TARGET_TZ="Asia/Seoul" ;;
            US) TARGET_TZ="America/New_York" ;; # 美国默认给东部，建议手输
            UK|GB) TARGET_TZ="Europe/London" ;;
            DE) TARGET_TZ="Europe/Berlin" ;;
            FR) TARGET_TZ="Europe/Paris" ;;
            RU) TARGET_TZ="Europe/Moscow" ;;
            AU) TARGET_TZ="Australia/Sydney" ;;
            VN) TARGET_TZ="Asia/Ho_Chi_Minh" ;;
            TH) TARGET_TZ="Asia/Bangkok" ;;
            ID) TARGET_TZ="Asia/Jakarta" ;;
            PH) TARGET_TZ="Asia/Manila" ;;
            *) 
                # 如果不是缩写，则假设用户输入的是完整时区名 (如 Asia/Shanghai)
                # 使用 timedatectl list-timezones 验证输入是否存在
                if timedatectl list-timezones | grep -qi "^$tz_input$"; then
                    # grep -i 忽略大小写，但我们需要标准的写法，所以重新获取一下
                    TARGET_TZ=$(timedatectl list-timezones | grep -i "^$tz_input$" | head -n 1)
                else
                    TARGET_TZ=""
                fi
                ;;
        esac

        if [ -n "$TARGET_TZ" ]; then
            echo -e "${GREEN}识别为有效时区: $TARGET_TZ${PLAIN}"
            break
        else
            echo -e "${RED}错误：无法识别的时区或代码 '$tz_input'。${PLAIN}"
            echo -e "请尝试输入标准时区名 (例如 Asia/Tokyo) 或检查缩写。"
        fi
    done
}

# 获取并验证时间格式 (HH:MM)
get_valid_time() {
    while true; do
        read -p "请输入每日重启时间 (24小时制 HH:MM，例如 03:30): " time_input
        if [[ $time_input =~ ^([0-9]|0[0-9]|1[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
            hour=$(echo $time_input | cut -d: -f1)
            minute=$(echo $time_input | cut -d: -f2)
            break
        else
            echo -e "${RED}格式错误！请输入 HH:MM 格式 (00:00 - 23:59)${PLAIN}"
        fi
    done
}

# 1. 安装逻辑
install_update() {
    echo -e "${CYAN}=== 开始配置自动更新与重启 ===${PLAIN}"
    
    # 步骤 1: 获取时区
    get_valid_timezone

    # 步骤 2: 获取时间
    get_valid_time
    
    echo -e "${CYAN}----------------------------------------${PLAIN}"
    echo -e "配置清单："
    echo -e "目标时区: ${YELLOW}$TARGET_TZ${PLAIN}"
    echo -e "重启时间: ${YELLOW}$hour:$minute${PLAIN} (每日)"
    echo -e "${CYAN}----------------------------------------${PLAIN}"

    # 步骤 3: 应用系统设置
    echo -e "${YELLOW}正在设置系统时区...${PLAIN}"
    timedatectl set-timezone "$TARGET_TZ"
    echo -e "${GREEN}系统时间已校准：$(date)${PLAIN}"

    # 步骤 4: 立即更新
    echo -e "${YELLOW}正在执行首次系统更新 (apt update & upgrade)...${PLAIN}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y && apt-get upgrade -y
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}系统更新成功！${PLAIN}"
    else
        echo -e "${RED}更新遇到小问题，但我们将继续设置定时任务。${PLAIN}"
    fi

    # 步骤 5: 写入 Cron
    echo -e "${YELLOW}正在写入定时任务...${PLAIN}"
    
    cat > ${CRON_FILE} <<EOF
# Auto Update & Reboot | Timezone: $TARGET_TZ
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

$minute $hour * * * root DEBIAN_FRONTEND=noninteractive apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; /sbin/reboot
EOF

    chmod 644 ${CRON_FILE}
    systemctl restart cron

    echo -e "${GREEN}==============================================${PLAIN}"
    echo -e "${GREEN}  安装成功！${PLAIN}"
    echo -e "${GREEN}  当前时区: $TARGET_TZ${PLAIN}"
    echo -e "${GREEN}  下次重启: 每天 $hour:$minute${PLAIN}"
    echo -e "${GREEN}==============================================${PLAIN}"
}

# 2. 卸载逻辑
uninstall_update() {
    echo -e "${YELLOW}正在卸载...${PLAIN}"
    if [ -f "${CRON_FILE}" ]; then
        rm -f "${CRON_FILE}"
        systemctl restart cron
        echo -e "${GREEN}已删除定时任务配置。${PLAIN}"
    else
        echo -e "${RED}未找到配置文件，无需卸载。${PLAIN}"
    fi
}

# 菜单
show_menu() {
    clear
    echo -e "${CYAN}==============================================${PLAIN}"
    echo -e "${CYAN}    Linux 自动更新神器 (Pro版)${PLAIN}"
    echo -e "${CYAN}==============================================${PLAIN}"
    echo -e "${GREEN} 1.${PLAIN} 设置自动更新 & 定时重启 (支持所有时区)"
    echo -e "${GREEN} 2.${PLAIN} 卸载自动更新 & 取消重启"
    echo -e "${GREEN} 3.${PLAIN} 退出"
    echo -e "${CYAN}==============================================${PLAIN}"
    
    read -p " 请输入选项 [1-3]: " num
    case "$num" in
        1) install_update ;;
        2) uninstall_update ;;
        3) exit 0 ;;
        *) echo -e "${RED}请输入正确数字${PLAIN}"; sleep 1; show_menu ;;
    esac
}

check_root
check_sys
show_menu
