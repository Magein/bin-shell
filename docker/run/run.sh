#!/bin/sh

# 引入配置文件
source ./config.sh

# 帮助信息
Usage(){
    echo "Usage:"
    echo "  run [options]"
    echo "  run -c /usr/local/conf -w /var/www -l"
    echo "Options:"
    echo "  -c, --check                 Check the running environment,If there is no output, satisfy"
    echo "  -h, --help                  Show information for help"
    echo "  -r, --run                   Run web environment"
    echo "  --composer                  Composer file storage location"
    echo "  --conf                      The location of nginx.conf php-fpm.conf php.ini storage"
    echo "      --nginx-conf            nginx.conf file storage location"
    echo "      --php-ini               php.ini file storage location"
    echo "      --php-fpm-conf          php-fpm.conf file storage location"
    echo "  --web                       Web program storage location"
    echo "  --log                       Log file storage location"
    echo "      --php-fpm-log           Php-fpm log file storage location"
    echo "      --nginx-log             Nginx log file storage location"
    echo "  --source                    Mirror source,If it is empty, use the configuration in the docker configuration file"
    echo "  --nginx                     Nginx image name"
    echo "  --php                       Php image name"
    echo "Default Value:"
    echo "  composer                    $PWD"
    echo "  conf                        /usr/local/docker/"
    echo "  nginx-conf                  /usr/local/conf/nginx.conf"
    echo "  php-ini                     /usr/local/conf/php.ini"
    echo "  php-fpm-conf                /usr/local/conf/php-fpm.conf"
    echo "  web                         /var/www/"
    echo "  log                         /var/log/"
    echo "  php-fpm-log                 /var/log/php/"
    echo "  nginx-log                   /var/log/nginx/"
    echo "  source                      registry.cn-hangzhou.aliyuncs.com/magein/"
    echo "  nginx                       alpine-nginx-1.13.2"
    echo "  php                         alpine-php-7.1.17"
}

# 检测web服务启动所需要的环境
Check(){
    # 是否已经安装docker
    if  [ -f /usr/bin/docker ]; then
        version=`docker -v | awk '{print $3}' | awk -F. '{print $1}'`
        if [ "$version" -lt 17 ]; then
            echo "docker version should greater 17.x"
            exit 1
        fi
    else
        echo "please install docker,version greater than 17.x"
        exit 1
    fi
}

# 创建目录
MakeDirectory(){
    for dir in "$@";
    do
        if [ ! -d "$dir" ];then
            mkdir -p "$dir"
        fi
    done
}

# 创建文件
MakeFile(){
     for name in "$@";
        do
            if [ ! -f "$name" ];then
                touch "$name"
            fi
    done
}

# 检测镜像是否已经拉取
CheckImage(){
    docker images | grep -w "$1" > /dev/null 2>&1
    if [ $? -eq 1 ];then
        # 没有匹配到
        return 0
    fi
    # 已经匹配到
    return  1
}

# 下载镜像
# docker 要先运行
Pull(){
    systemctl status docker | grep "Active: inactive (dead)" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        Segmentation ''
        echo "Please run docker ( systemctl start docker )"
        echo ''
        exit 0
    fi

    for registry in "$@";
        do
        CheckImage "$registry"
        if [ $? -eq 0 ]; then
            docker pull "$registry" > /dev/null 2>&1
            CheckImage "$registry"
            if [ $? -eq 0 ]; then
                echo "Pull $registry fail"
                echo "exit"
                exit 1
            fi
            echo "Complete"
        fi
    done
}

# 基础参数
source="registry.cn-hangzhou.aliyuncs.com/magein/"
nginx="alpine-nginx-1.13.2"
php="alpine-php-7.1.17"
composer="$PWD"
conf="/usr/local/docker/"

# 接收命令行传递的参数
options=$(getopt -o c,h --long help,composer:,conf:,nginx-conf:php-ini:,php-fpm-conf:,web:,log:,nginx-log:,php-fpm-log:,nginx-log:source::,nginx:php: -n "error" -- "$@")
if [ $? -eq 1 ]; then
    exit 0
fi

eval set -- "${options}"

while true;
do
    case $1 in
        -c|--check)
            Check
            exit 0
        ;;
        -h|--help)
            Usage
            exit 0
        ;;
        --composer)
            composer=$2
            shift 2
        ;;
        --conf)
            conf=$2
            shift 2
        ;;
        --web)
            web=$2
            shift 2
        ;;
        --log)
            log=$2
            shift 2
        ;;
        --php-log)
            nginx_log=$2
            shift 2
        ;;
        --nginx-log)
            nginx_log=$2
            shift 2
        ;;
        --source)
            source=$2
            shift 2
        ;;
        --nginx)
            nginx=$2
            shift 2
        ;;
        --php)
            php=$2
            shift 2
        ;;
        *)
            break
        ;;
    esac
done

# 根据传递的参数生成响应的变量
composer_file="${composer}composer.yml"
nginx_conf="${conf}nginx.conf"
php_ini="${conf}php.ini"
php_fpm_conf="${conf}php-fpm.conf"
pool="${conf}php-fpm.d/"
pool_conf="${pool}www.conf"
web="/var/www/"
log="/var/log/"
nginx_log="${log}nginx/"
php_fpm_log="${log}php/"

# 检测安装环境
Check
Segmentation "Check pass"

# 拉取镜像
if [ -n "$source" ]; then
    nginx="$source$nginx"
    php="$source$php"
fi
Pull "$nginx" "$php"

# 创建配置文件
Segmentation "Start Create configuration file"

# 检查基础目录
# 1. 检测是否存在
#   1.1 不存在则创建
#   1.2 修改所属组为docker
#   1.3 修改权限为 775
# 2. 检测是否有可写权限
if [ ! -d "$conf" ]; then
    MakeDirectory "$conf"
    chgrp docker "$conf"
    chmod 775 "$conf"
elif [ ! -w "$conf" ];then
    Segmentation "Configuration file directory cannot be written"
    echo "  Storage location: $conf"
    exit 0
fi

# 检测日志文件是否有可写权限
if [ ! -w "$log" ]; then
    Segmentation "Log file directory cannot be written"
    echo "  Storage location: $log"
    echo "  Recommended use setfacl"
    exit 0
fi

# 创建相关目录
MakeDirectory "$web" "$log" "$nginx_log" "$php_fpm_log" "$pool" "$composer"

# 检测docker启动文件存放目录是否有可写权限
if [ ! -w "$composer" ]; then
    Segmentation "Composer file directory cannot be written"
    echo "  Storage location: $composer"
    echo "  You can use \"--composer\" option to change storage location"
    exit 0
fi
MakeFile "$nginx_conf" "$php_ini" "$php_fpm_conf" "$pool_conf" "$composer_file"

Nginx   "$nginx_conf"
Ini     "$php_ini"
Fpm     "$php_fpm_conf"
Pool    "$pool_conf"

Yml(){
    {
        echo "version: \"3\"
services:
  php:
    image: $php
    ports:
      - 9000:9000
    volumes:
      - $conf:/usr/local/etc/
      - $php_fpm_log:/usr/local/var/log
      - $web:/usr/local/nginx/html
    deploy:
      replicas: 1
  nginx:
    image: $nginx
    ports:
      - 80:80
    volumes:
      - $conf/nginx.conf:/usr/local/nginx/conf/nginx.conf
      - $nginx_log:/usr/local/nginx/logs/
      - $web:/usr/local/nginx/html
    deploy:
      replicas: 1
"
    } | tee "$composer_file" > /dev/null

    Segmentation "Create composer.yml file complete" "$composer_file"
}

Yml

Segmentation "You can use the following commands to run the web service:
\n  docker swarm init
\n  docker stack deploy -c $composer_file web_service"
#echo ""
#echo "##########################################################"
#echo "You can use the following commands to run the web service"
#echo "systemctl start docker"
#echo "docker swarm init"
#echo "docker stack deploy -c $composer_file web_service"