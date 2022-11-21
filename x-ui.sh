#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Error: You must run this script as root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    LOGE "If the system version is not detected, please contact the author\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        LOGE "please use CentOS 7 Or a higher version of the system! \n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "please use Ubuntu 16 Or a higher version of the system! \n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "please use Debian 8 Or a higher version of the system! \n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [default$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Whether to restart the panel, restart the panel will restart XRAY" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/NidukaAkalanka/x-ui-english.old/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will reinstall the latest version. The data will not be lost. Do you continue?" "n"
    if [[ $? != 0 ]]; then
        LOGE "Cancelled"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/NidukaAkalanka/x-ui-english.old/main/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "Update is completed, panel has been automatically restarted "
        exit 0
    fi
}

uninstall() {
    confirm "Are you sure to uninstall the Panel and Xray?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "If you want to delete this script successfully, exit the script and run ${green}rm /usr/bin/x-ui -f${plain} Delete"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure to reset? Username and Password will be admin" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Username and password have been reset to ${green}admin${plain}!Please restart the panel now"
    confirm_restart
}

reset_config() {
    confirm "Are you sure to reset all the panel settings, the account data will not be lost, the username and password will not change" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "All panel settings have been reset to the default value. Now please restart the panel and use the default ${green}54321${plain} Port access panel"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Enter Panel Port[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Cancelled"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "After the setting new port, please restart the panel and use the newly set port ${green}${port}${plain} Access panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "Panel is running, no need to start again, if you need to restart, please choose to restart"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui Successfully Started"
        else
            LOGE "Panel failed to start, maybe because the startup time exceeded two seconds, please check the log information later"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "Panel has stopped, no need to stop again"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui and xray stop success"
        else
            LOGE "Panel stops failing, maybe because the stop time exceeds two seconds, please check the log information later"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui and xray restart success"
    else
        LOGE "Panel failed to restart, maybe because the startup time exceeded two seconds, please check the log information later"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui Enable success"
    else
        LOGE "x-ui Enable failed"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui Disable success"
    else
        LOGE "x-ui Disable failed"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://raw.githubusercontent.com/NidukaAkalanka/x-ui-english.old/main/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Update download failed, please check whether the machine can connect to Github"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "Update success. Please re-run the script" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "Panel has been installed, please do not install it again"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Please install the panel first"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Panel Status: ${green}Runing${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Panel Status: ${yellow}Not running${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Panel Status: ${red}Not Installed${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to start with boot: ${green}Yes${plain}"
    else
        echo -e "Whether to start with boot: ${red}No${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "Xray Status: ${green}Runing${plain}"
    else
        echo -e "Xray Status: ${red}Not Running${plain}"
    fi
}

ssl_cert_issue() {
    local method=""
    echo -E ""
    LOGD "********Usage********"
    LOGI "This shell script will use acme to issue SSL certs."
    LOGI "Here, we provide two methods for issuing certs:"
    LOGI "Method 1:acme standalone mode; need to keep port:80 open (Recommended)"
    LOGI "Method 2:acme DNS API mode; need to have Cloudflare Global API Key (If 1st method fails)"
    LOGI "Certs will be installed in /root/cert/ directory"
    read -p "Please choose which method do you want (type 1 or 2)": method
    LOGI "You have chosen method:${method}"

    if [ "${method}" == "1" ]; then
        ssl_cert_issue_standalone
    elif [ "${method}" == "2" ]; then
        ssl_cert_issue_by_cloudflare
    else
        LOGE "Invalid input, please check it..."
        exit 1
    fi
}

install_acme() {
    cd ~
    LOGI "Installing acme..."
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        LOGE "installing acme failed!"
        return 1
    else
        LOGI "installing acme succeed"
    fi
    return 0
}

#method for standalone mode
ssl_cert_issue_standalone() {
    #install acme first
    install_acme
    if [ $? -ne 0 ]; then
        LOGE "Installing acme failed, please check logs"
        exit 1
    fi
    #install socat second
    if [[ x"${release}" == x"centos" ]]; then
        yum install socat -y
    else
        apt install socat -y
    fi
    if [ $? -ne 0 ]; then
        LOGE "Install socat failed,please check logs"
        exit 1
    else
        LOGI "Install socat succeed..."
    fi
    #creat a directory for install cert
    certPath=/root/cert
    if [ ! -d "$certPath" ]; then
        mkdir $certPath
    else
        rm -rf $certPath
        mkdir $certPath
    fi
    #get the domain here,and we need verify it
    local domain=""
    read -p "Please input your domain:" domain
    LOGD "Your domain is:${domain},check it..."
    #here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
    if [ ${currentCert} == ${domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        LOGE "System already have certs here, can not issue again, current certs details:"
        LOGI "$certInfo"
        exit 1
    else
        LOGI "Your domain is ready for issuing cert now..."
    fi
    #get needed port here
    local WebPort=80
    read -p "Please choose which port do you use, default will be 80 port:" WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        LOGE "Your input ${WebPort} is invalid, please use the default port"
    fi
    LOGI "Using port:${WebPort} to issue certs, please make sure this port is open..."
    #NOTE:This should be handled by user
    #open the port and kill the occupied progress
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        LOGE "Issue certs failed, please check logs"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGE "Issue certs succeed!installing certs now..."
    fi
    #install cert
    ~/.acme.sh/acme.sh --installcert -d ${domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${domain}.cer --key-file /root/cert/${domain}.key \
        --fullchain-file /root/cert/fullchain.cer

    if [ $? -ne 0 ]; then
        LOGE "Installing certs failed. exited."
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGI "Installing certs succeed! enabling auto renew now..."
    fi
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        LOGE "Enabling auto renew  failed. certs details:"
        ls -lah cert
        chmod 755 $certPath
        exit 1
    else
        LOGI "Enabling auto renew succeed! certs details:"
        ls -lah cert
        chmod 755 $certPath
    fi

}

#method for DNS API mode
ssl_cert_issue_by_cloudflare() {
    echo -E ""
    LOGD "******Requirements******"
    LOGI "1.Knowing Cloudflare account associated email"
    LOGI "2.Knowing Cloudflare Global API Key"
    LOGI "3.Your domain use Cloudflare as resolver"
    confirm "I have confirmed all these info above[y/n]" "y"
    if [ $? -eq 0 ]; then
        install_acme
        if [ $? -ne 0 ]; then
            LOGE "Installing acme failed. Please check logs"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "Please input your domain (example.com):"
        read -p "Input your domain here:" CF_Domain
        LOGD "your domain is:${CF_Domain},check it..."
        #here we need to judge whether there exists cert already
        local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
        if [ ${currentCert} == ${CF_Domain} ]; then
            local certInfo=$(~/.acme.sh/acme.sh --list)
            LOGE "System already have certs. Can not be issued again. Current certs details:"
            LOGI "$certInfo"
            exit 1
        else
            LOGI "Your domain is ready for issuing cert now..."
        fi
        LOGD "Please input your Cloudflare Global API key:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "Your cloudflare global API key is:${CF_GlobalKey}"
        LOGD "Please input your Cloudflare account email:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "Your cloudflare account email:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "Changing the default CA to Lets'Encrypt failed. Exited"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "Issuing cert failed. Exited"
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
            LOGI "Issuing cert succeed! Installing now..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
            --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
            --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "Installing cert failed. Exited"
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
            LOGI "Installing cert succeed! Enabling auto renew now..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "Enabling auto renew failed. Exited"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "Enabling auto renew succeed! cert details:"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}


show_usage() {
    echo "------------------------------------------"
    echo "${green}\\  //  ||   || ||${plain}"
    echo "${green} \\//   ||   || ||${plain}"
    echo "${green} //\\   ||___|| ||${plain}"
    echo "${green}//  \\  |_____| ||${plain}"
    echo "------------------------------------------"
    echo "x-ui Management script usage: "
    echo "------------------------------------------"
    echo "x-ui              - Show the management menu"
    echo "x-ui start        - start up x-ui panel"
    echo "x-ui stop         - stop x-ui panel"
    echo "x-ui restart      - restart x-ui panel"
    echo "x-ui status       - view x-ui status"
    echo "x-ui enable       - enable x-ui service"
    echo "x-ui disable      - disable x-ui service"
    echo "x-ui log          - Check x-ui log"
    echo "x-ui v2-ui        - switch v2-ui to x-ui"
    echo "x-ui update       - update x-ui panel"
    echo "x-ui install      - install x-ui panel"
    echo "x-ui uninstall    - uninstall x-ui panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
------------------------------------------
  ${green}\\  //  ||   || ||${plain}
  ${green} \\//   ||   || ||${plain}
  ${green} //\\   ||___|| ||${plain}
  ${green}//  \\  |_____| ||${plain}
------------------------------------------
  ${green}x-ui Panel management script${plain}
  ${green}0.${plain} Exit script
————————————————
  ${green}1.${plain} Install x-ui
  ${green}2.${plain} Reinstall x-ui
  ${green}3.${plain} Uninstall x-ui
————————————————
  ${green}4.${plain} Reset the username password
  ${green}5.${plain} Reset panel settings
  ${green}6.${plain} Set panel port
  ${green}7.${plain} Check panel settings
————————————————
  ${green}8.${plain} Start x-ui
  ${green}9.${plain} Stop x-ui
  ${green}10.${plain} Restart x-ui
  ${green}11.${plain} Check x-ui status
  ${green}12.${plain} Check x-ui Log
————————————————
  ${green}13.${plain} Set x-ui auto start at boot
  ${green}14.${plain} Stop x-ui auto start at boot
————————————————
  ${green}15.${plain} A key installation bbr (The latest kernel)
  ${green}16.${plain} One -click application SSL certificate(Acme Certbot)
 "
    show_status
    echo && read -p "Please enter the selection [0-16]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    *)
        LOGE "Please enter the correct number [0-16]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
