#!/bin/sh

# 基础参数
source="registry.cn-hangzhou.aliyuncs.com/magein/"
nginx="alpine-nginx-1.13.2"
php="alpine-php-7.1.17"
composer="$PWD"
conf="/usr/local/docker/"
only_check=false

source ./functions/Check.sh
source ./functions/Make.sh
source ./functions/Usage.sh

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
            only_check=true
            shift 1
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
composer_file="${composer}/composer.yml"
nginx_conf_path="${conf}nginx/"
nginx_conf="${nginx_conf_path}nginx.conf"

php_conf_path="${conf}php/"
php_ini="${php_conf_path}php.ini"
php_fpm_conf="${php_conf_path}php-fpm.conf"
pool="${php_conf_path}php-fpm.d/"
pool_conf="${pool}www.conf"

web="/var/www/"
log="/var/log/"
nginx_log="${log}nginx/"
php_fpm_log="${log}php/"

# 创建配置文件存放目录
MakeDirectory "$conf"

# 检测执行环境
Check "$conf" "$log" "$composer"

# 指定了 -c 或者 --check 参数，则值输出检测结果  不继续往下执行
if [ "$only_check" == "true" ]; then
    exit 0
fi

# 如果检测结果中有失败的项，则不逆序往下执行
if [ "${#CheckFail[@]}" -ne 0 ]; then
    CheckFail
    exit 0
fi

# --nginx --php参数指定了拉取的镜像
# 如果指定了镜像源，则拼接起来
if [ -n "$source" ]; then
    nginx="$source$nginx"
    php="$source$php"
fi

# 輸出分隔符
Segmentation(){
    echo ""
    echo "#################################################################"
    echo ""
    echo -e $1
}

# 写入配置文件
# 文件是从 ./conf目录下copy进去的，所以修改应该修改conf中的，并且删除原来的，
Write(){
    Segmentation "Start write configure file"
    for i in "$@";
    do
        filename=$(echo "$i" | awk -F/ '{print $NF}')
        filepath="./conf/$filename"
        if [ -f "$filepath" ]; then
            cat "$filepath" | tee "$i" > /dev/null 2>&1
            if [ $? -eq 1 ]; then
                echo "  Write $i fail"
                exit 0
            else
                echo "  Write $i complete"
            fi
        fi
    done

    echo "Write all complete"
}

# 拉取镜像
Pull(){
    for registry in "$@";
        do
        CheckImage "$registry"
        if [ $? -ne 0 ]; then
            Segmentation "Pull $registry ,Please wait a moment"
            docker pull "$registry" > /dev/null 2>&1
            CheckImage "$registry"
            if [ $? -eq 0 ]; then
                echo "Pull fail"
                echo "exit"
                exit 1
            fi
            echo "Pull success"
        fi
    done
}

Pull "$nginx" "$php"

# 创建相关目录以及相关文件
MakeDirectory "$web" "$nginx_conf_path" "$php_conf_path" "$log" "$nginx_log" "$php_fpm_log" "$pool" "$composer"
MakeFile "$nginx_conf" "$php_ini" "$php_fpm_conf" "$pool_conf" "$composer_file"
Write "$php_ini" "$nginx_conf" "$php_fpm_conf" "$pool_conf"

Yml(){
    {
        echo "version: \"3\"
services:
  php:
    image: $php
    ports:
        - 9000:9000
    volumes:
        - $php_conf_path:/usr/local/etc/
        - $php_fpm_log:/usr/local/var/log
        - $web:/usr/local/nginx/html
    deploy:
        # mode 默认值 replicated，可选值 global
        mode: replicated
        replicas: 1
        # 容器异常退出时候的处理方式，如内存不足导致
        restart_policy:
            # 配置是否以及如何在容器退出时重新启动容器
            # 可选值 none on-failure any(default)
            condition: on-failure
            # 重新尝试启动之间的等待时间，默认值为0
            delay: 0s
            # 在放弃之前尝试重新启动容器的次数（默认值：永不放弃） 0 表示不尝试
            max_attempts: 5
  nginx:
    image: $nginx
    ports:
        - 80:80
    volumes:
        - $nginx_conf:/usr/local/nginx/conf/nginx.conf
        - $nginx_log:/usr/local/nginx/logs/
        - $web:/usr/local/nginx/html
    deploy:
        mode: replicated
        replicas: 1
"
    } | tee "$composer_file" > /dev/null

    Segmentation "Create composer.yml file complete"
}

Yml

Segmentation "You can use the following commands to run the web service:
\n  docker swarm init
\n  docker stack deploy -c $composer_file web_service"