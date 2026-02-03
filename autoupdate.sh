#!/bin/bash

# ==============================================================
# 脚本名称: Auto Update & Reboot Manager (Kuala Lumpur Edition)
# 功能: 自动更新、设置吉隆坡时区、每日凌晨03:30重启
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

# 1. 安装自动更新并开机启动
install_update() {
    echo -e "${CYAN}正在初始化安装配置...${PLAIN}"
    
    # --- 修改点：设置时区为吉隆坡 ---
    echo -e "${YELLOW}正在设置时区为 Asia/Kuala_Lumpur (吉隆坡时间)...${PLAIN}"
    timedatectl set-timezone Asia/Kuala_Lumpur
    echo -e "${GREEN}时区设置完成，当前时间：$(date)${PLAIN}"

    # 立即执行一次更新
    echo -e "${YELLOW}正在立即执行系统更新 (apt update && upgrade)...${PLAIN}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y && apt-get upgrade -y
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}系统更新成功！${PLAIN}"
    else
        echo -e "${RED}系统更新过程中出现错误，但我们将继续设置定时任务。${PLAIN}"
    fi

    # 写入定时任务
    echo -e "${YELLOW}正在写入定时任务 (每天吉隆坡时间 03:30 更新并重启)...${PLAIN}"
    
    cat > ${CRON_FILE} <<EOF
# 每天吉隆坡时间 03:30 自动更新并重启
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

30 03 * * * root DEBIAN_FRONTEND=noninteractive apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; /sbin/reboot
EOF

    chmod 644 ${CRON_FILE}
    systemctl restart cron

    echo -e "${GREEN}==============================================${PLAIN}"
    echo -e "${GREEN}  安装完成！${PLAIN}"
    echo -e "${GREEN}  1. 系统时区已修正为: Asia/Kuala_Lumpur${PLAIN}"
    echo -e "${GREEN}  2. 已执行一次完整更新${PLAIN}"
    echo -e "${GREEN}  3. 已设置计划任务：每天 03:30 自动更新并重启${PLAIN}"
    echo -e "${GREEN}==============================================${PLAIN}"
}

# 2. 卸载自动更新并清理
uninstall_update() {
    echo -e "${YELLOW}正在卸载自动更新及重启任务...${PLAIN}"
    
    if [ -f "${CRON_FILE}" ]; then
        rm -f "${CRON_FILE}"
        systemctl restart cron
        echo -e "${GREEN}已删除定时任务文件。${PLAIN}"
        echo -e "${GREEN}自动更新和定时重启已取消。${PLAIN}"
    else
        echo -e "${RED}未检测到安装过的任务文件，无需卸载。${PLAIN}"
    fi
}

# 主菜单 UI
show_menu() {
    clear
    echo -e "${CYAN}==============================================${PLAIN}"
    echo -e "${CYAN}    Linux 自动更新助手 (吉隆坡时区版)${PLAIN}"
    echo -e "${CYAN}==============================================${PLAIN}"
    echo -e "${GREEN} 1.${PLAIN} 安装自动更新并开机启动 (每天 03:30 重启)"
    echo -e "${GREEN} 2.${PLAIN} 卸载自动更新并开机启动 (删除重启任务)"
    echo -e "${GREEN} 3.${PLAIN} 退出脚本"
    echo -e "${CYAN}==============================================${PLAIN}"
    
    read -p " 请输入选项 [1-3]: " num
    
    case "$num" in
        1)
            install_update
            ;;
        2)
            uninstall_update
            ;;
        3)
            echo -e "${GREEN}退出脚本。${PLAIN}"
            exit 0
            ;;
        *)
            echo -e "${RED}输入错误，请输入 1-3 之间的数字。${PLAIN}"
            sleep 2
            show_menu
            ;;
    esac
}

# 执行逻辑
check_root
check_sys
show_menu
