#!/bin/sh

# 帮助信息
usage(){
    echo "Usage:"
    echo "  run [options]"
    echo "  run -c /usr/local/conf -w /var/www -l"
    echo "Options:"
    echo "  -c, --check                 Check the running environment"
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
check(){
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
    echo "Check Pass"
}

# 创建目录
make_directory(){
    for dir in "$@";
        do
            if [ ! -d "$dir" ];then
                mkdir -p "$dir"
            fi
    done
}

# 创建文件
make_file(){
     for name in "$@";
        do
            if [ ! -f "$name" ];then
                touch "$name"
            fi
    done
}

image(){
    docker images | grep -w "$1" > /dev/null
    if [ $? -eq 1 ];then
        # 没有匹配到
        return 0
    fi
    # 已经匹配到
    return  1
}

# 下载镜像
pull(){
    for registry in "$@";
        do
        image "$registry"
        if [ $? -eq 0 ]; then
            docker pull "$registry" > /dev/null 2>&1
            image "$registry"
            if [ $? -eq 0 ]; then
                echo "Pull $registry fail"
                echo "exit"
                exit 1
            fi
            echo "Complete"
        fi
    done
}

source="registry.cn-hangzhou.aliyuncs.com/magein/"
nginx="alpine-nginx-1.13.2"
php="alpine-php-7.1.17"

composer="$PWD"
composer_file="$composer/composer.yml"
conf="/usr/local/docker/"

nginx_conf="${conf}nginx.conf"
php_ini="${conf}php.ini"
php_fpm_conf="${conf}php-fpm.conf"
pool="${conf}php-fpm.d/"
pool_conf="${pool}www.conf"
web="/var/www/"
log="/var/log/"
nginx_log="${log}nginx/"
php_fpm_log="${log}php/"

options=$(getopt -o c,h --long composer:,conf:,nginx-conf:php-ini:,php-fpm-conf:,web:,log:,nginx-log:,php-fpm-log:,nginx-log:source::,nginx:php: -n "error" -- "$@")

if [ ! $? ]; then
    exit 1
fi

eval set -- "${options}"

while true;
do
    case $1 in
        -c|--check)
            check
            exit 0
        ;;
        -h|--help)
            usage
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

# 引入配置文件
source ./config.sh

check

segmentation "Check pass"

if [ -n "$source" ]; then
    nginx="$source$nginx"
    php="$source$php"
fi

segmentation "Pull images"
pull "$nginx" "$php"

segmentation "Start Create configuration file"

# 创建目录
make_directory "$conf" "$web" "$log" "$nginx_log" "$php_fpm_log" "$pool" "$composer"

# 创建文件

make_file "$nginx_conf" "$php_ini" "$php_fpm_conf" "$pool_conf" "$composer_file"

nginx   "$nginx_conf"
ini     "$php_ini"
fpm     "$php_fpm_conf"
pool    "$pool_conf"

yml(){
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

    segmentation "Create composer.yml file complete" "$composer_file"
}

yml

segmentation "You can use the following commands to run the web service:
\n  systemctl start docker
\n  docker swarm init
\n  docker stack deploy -c $composer_file web_service"
#echo ""
#echo "##########################################################"
#echo "You can use the following commands to run the web service"
#echo "systemctl start docker"
#echo "docker swarm init"
#echo "docker stack deploy -c $composer_file web_service"