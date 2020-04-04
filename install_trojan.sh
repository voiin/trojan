#!/bin/bash
if [[ ! -e '/etc/redhat-release' ]];then
	echo -e "\033[31m 该脚本不支持此系统！\033[0m"
	exit
fi

ver='v1.8'
function blue(){
    echo -e "\033[34m\033[01m $1 \033[0m"
}
function green(){
    echo -e "\033[32m\033[01m $1 \033[0m"
}
function red(){
    echo -e "\033[31m\033[01m $1 \033[0m"
}
function grey(){
    echo -e "\033[36m\033[01m $1 \033[0m"
}
netstat >> /dev/null 2>&1
if [[ $(echo $?) != 0 ]];then
    yum -y install net-tools
fi

check_status(){
    check_trojan_status(){
        netstat -ntlp | grep trojan >> /dev/null 2>&1
        if [[ $(echo $?) != 0 ]];then
            red "未运行"
        else
            green "已运行"
        fi 
    }
    if [[ ! -e '/usr/local/bin/trojan' ]] || [[ ! -f '/usr/local/etc/trojan/config.json' ]];then
    	echo -n "当前状态: trojan"
        echo -en "\033[31m\033[01m 未安装\033[0m"
        check_trojan_status
    else
	echo -n "当前状态: trojan"
        echo -en "\033[32m\033[01m 已安装\033[0m"
        check_trojan_status
    fi
}

install_nginx(){
    yum -y update && yum -y install sudo
    sudo yum -y install yum-utils
    nginx -s stop
    rm -rf /usr/sbin/nginx
    rm -rf /etc/nginx
    rm -rf /etc/init.d/nginx
    yum -y remove nginx
    touch /etc/yum.repos.d/nginx.repo

    cat > /etc/yum.repos.d/nginx.repo << "EOF"
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
    sudo yum-config-manager --enable nginx-mainline
    sudo yum -y install nginx
}
cert_menu(){ 
    sudo yum -y install socat openssl curl cronie vim tar
    sudo systemctl start crond
    sudo systemctl enable crond
    sleep 2s
    curl  https://get.acme.sh | sh
    echo -e "_________________________"
    echo -e "\033[32m 1.\033[0m Aliyun"
    echo -e "_________________________"
    echo -e "\033[32m 2.\033[0m CloudFlare"
    echo -e "_________________________"
    echo -e "\033[32m 3.\033[0m Vultr"
    echo -e "_________________________"
    read -p "请选择你使用的DNS服务器[1-3]:" dns_name
    case "$dns_name" in
      1)
          Dns='Ali'
          dns='ali'
          config_cert
          ;;
      2)
          Dns='CF'
          dns='cf'
          config_cert
          ;;
      3)
          Dns='VULTR_API'
          dns='vultr'
          config_cert
          ;;
      *)
          clear
          echo "输入正确数字"
          sleep 3s
          cert_menu
          ;;
    esac                     
}
config_cert(){
    if [[ "$dns_name" == "1" ]];then
        blue "========================="
        read -p "输入你的APIkey：" APIkey
        blue "========================="
        read -p "输入你的APISecret：" APISecret
        blue "========================="
        export Ali_Secret="$APISecret"
    else
        if [[ "$dns_name" == "2" ]];then
            blue "========================="
            read -p "输入你的APIkey：" APIkey
            blue "========================="
            read -p "输入你的CF_Email：" APISecret
            blue "========================="
            export CF_Email="$APISecret"
        else
            blue "========================="
            read -p "输入你的APIkey：" APIkey
            blue "========================="
        fi             
    fi
    read -p "输入已解析到服务器的域名：" domain
    blue "========================="
    export ${Dns}_Key="$APIkey"
    sudo mkdir /usr/local/etc/${domain}
    .acme.sh/acme.sh --issue -d ${domain} -d www.${domain} --dns dns_${dns}
    .acme.sh/acme.sh --install-cert -d ${domain} -d www.${domain} --key-file /usr/local/etc/${domain}/private.key --fullchain-file /usr/local/etc/${domain}/fullchain.crt
    .acme.sh/acme.sh  --upgrade  --auto-upgrade
}

install_trojan(){
    yum -y install xz
    sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"
    sudo cp /usr/local/etc/trojan/config.json /usr/local/etc/trojan/config.json.bak
cat > /usr/local/etc/trojan/config.json << "EOF"
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": [
  	"password1"
  ],
  "log_level": 1,
  "ssl": {
    "cert": "/usr/local/etc/certfiles/certificate.crt",
    "key": "/usr/local/etc/certfiles/private.key",
    "key_password": "",
    "cipher": "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256",
    "prefer_server_cipher": true,
    "alpn": [
      "http/1.1"
    ],
    "reuse_session": true,
    "session_ticket": false,
    "session_timeout": 600,
    "plain_http_response":  "",
    "curves": "",
    "dhparam": ""
  },
  "tcp": {
    "prefer_ipv4": false,
    "no_delay": true,
    "keep_alive": true,
    "fast_open": false,
    "fast_open_qlen": 20
  },
  "mysql": {
    "enabled": false,
    "server_addr": "127.0.0.1",
    "server_port": 3306,
    "database": "trojan",
    "username": "trojan",
    "password": ""
  }
}
EOF
    set_passwd(){
        blue "++++++++++++++++++++++++"
    	read -p "请输入为trojan设置的密码：" passwd
        blue "++++++++++++++++++++++++"
	read -p "请再次输入密码：" passwd1
        blue "++++++++++++++++++++++++"
    }
    for i in $(seq 1 10)
    do
      set_passwd
      if [ "$passwd" == "$passwd1" ];then
	  break
      else
          red "两次输入不一致，请重新输入！"
      fi
    done
    sed -i "s/password1/$passwd/" /usr/local/etc/trojan/config.json
    sudo systemctl daemon-reload
    echo "0 0 1 * * killall -s SIGUSR1 trojan" >> /var/spool/cron/$(whoami)
}  

config_nginx(){
    rm -rf /etc/nginx/conf.d/default.conf
    touch /etc/nginx/conf.d/0.trojan.conf
    ip_name=$(curl ifconfig.me)
    cat > /etc/nginx/conf.d/0.trojan.conf << "EOF"
server {
    listen 127.0.0.1:80 default_server;

    server_name <tdom.ml>;

    location / {
        proxy_pass https://github.com/voiin;
        proxy_set_header Host $proxy_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Remote-Port $proxy_add_x_forwarded_for;
        proxy_set_header X-Remote-Port $remote_port;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }
}

server {
    listen 127.0.0.1:80;

    server_name <10.10.10.10>;

    return 301 https://<tdom.ml>$request_uri;
}

server {
    listen 0.0.0.0:80;
    listen [::]:80;

    server_name _;

    return 301 https://<tdom.ml>$request_uri;
}
EOF
    sed -i "s/<tdom.ml>/$domain/" /etc/nginx/conf.d/0.trojan.conf
    sed -i "s/<10.10.10.10>/${ip_name}/" /etc/nginx/conf.d/0.trojan.conf
}

start_trojan(){
    nginx -t
    nginx -c /etc/nginx/nginx.conf
    nginx -s reload
    systemctl restart trojan
    systemctl enable trojan
    systemctl enable nginx
    sleep 5
    green "--------------------"
    green "--------------------"
    green "###trojan启动完成###"
    green "--------------------"
    green "--------------------"
}

remove_trojan(){
    systemctl stop trojan
    rm -rf .acme.sh
    rm -rf /var/spool/cron/$(whoami)
    rm -rf /etc/systemd/system/trojan.service
    rm -rf /etc/nginx/conf.d/0.trojan.conf
    rm -rf /usr/local/etc/certfiles
    rm -rf /usr/local/bin/trojan 
    rm -rf /usr/local/etc/trojan/config.json
    sleep 5
    green "###trojan卸载完成###"
}

start_menu(){
    clear 
    echo -n "trojan一键安装管理脚本" 
    red "[${ver}]"
grey "===================================
#  System Required: CentOS 7+,Debian 9+,Ubuntu 16+
#  Version: 1.8
#  Author: 韦岐
#  Blogs: https://voiin.com && http://www.axrni.cn
==================================="
echo -e "\033[32m 1.\033[0m 安装trojan    \033[34m__##@=@#\\ \033[0m
 ______________    \033[34m++ ####\033[0m                
\033[32m 2.\033[0m 停止trojan         \033[34m###                 ---\033[0m
 ______________        \033[34m###   +++++++++   ++\033[0m
\033[32m 3.\033[0m 重启trojan         \033[34m\#\\####//##//###+++ \033[0m
 ______________         \033[34m||####//++//###\033[0m          
\033[32m 4.\033[0m 卸载trojan           \033[34m= =       = =\033[0m          
 ______________         \033[34m=   =     =   =\033[0m
\033[32m 5.\033[0m 退出脚本           \033[34m=    =   =    =\033[0m"
grey "==================================="
    check_status
    read -p "请输入数字[1-5]:" num
    case "$num" in
        1)
	install_nginx
	cert_menu
	install_trojan
	config_nginx
	start_trojan
	;;
	2)
	systemctl stop trojan
	;;
	3)
	systemctl restart trojan
	;;
        4)
	remove_trojan
	;;
        5)
	exit 1
	;;
        *)
	clear
	red "请输入正确数字"
	sleep 5s
	start_menu
	;;
    esac
}
start_menu

