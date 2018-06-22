#!/bin/sh

# 显示帮助信息
usage(){
    echo "Usage:"
    echo "  start [options]"
    echo "  start -o --version 17.09.0.ce-1.el7.centos"
    echo "Options:"
    echo "  -c, --check              Check install environment"
    echo "  -h, --help               Show information for help"
    echo "  -q, --quiet              Quiet operation"
    echo "  -r, --remove             If already installed,then remove"
    echo "  -s, --show               Display the docker version of the optional installation"
    echo "  -v, --version            The version of the docker to install"
}

# 显示可选的docker版本
show(){
    registries=$(yum list docker-ce --showduplicates | sort -r | grep docker-ce)

    echo -e "$registries"
}

# 检测系统环境
check(){
    result="true"
    # 检测是否为centOS系统
    cat /etc/redhat-release | grep CentOS > /dev/null 2>&1
    if [ $? -eq 1 ]; then
        result="false"
    fi
    echo "CentOS System:                $result"

    # 检测内核版本
    kernel=$(uname -r | awk -F. '{print $1}')
    if [ "$kernel" -lt 3 ]; then
        result="false"
    fi
    echo "Kernel version:               $result"

    # 检测是否有yum权限
    if [ "$USER" != "root" ]; then
        sudo -l | grep /usr/bin/yum > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            result="false"
        fi
    fi
    echo "Yum permission:               $result"

    # 检测是否有yum-config-manager权限
    sudo -l | grep /usr/bin/yum-config-manager > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        result="false"
    fi
    echo "Config manager permission:    $result"

    # 是否已经安装docker
    if [ -f /usr/bin/docker ]; then
        result=$(docker --version | awk '{print $3}' | awk -F, '{print $1}')
        exist_version="$result"
    else
        result=null
    fi
    echo "Installed docker version:     $result"

    return 0
}

# 安装docker
install(){

    old=(docker \
            docker-client \
            docker-client-latest \
            docker-common \
            docker-latest \
            docker-latest-logrotate \
            docker-logrotate \
            docker-selinux \
            docker-engine-selinux \
            docker-engine
            )

    dependent=(yum-utils \
            device-mapper-persistent-data \
            lvm2
         )

    if [ -z $1 ]; then
        version=`"$registries" | awk 'NR==1{print $2}'`
    else
        version=$1
    fi

    echo ''
    echo "I will install version $version for you"

    echo 'step 1'
    sudo yum -y remove "${old[@]}" > /dev/null 2>&1
    echo 'step 2'
    sudo yum -y install "${dependent[@]}" > /dev/null 2>&1
    echo 'step 3'
    sudo yum-config-manager  --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
    echo 'step 4'
    sudo yum -y install docker-ce-"$version" > /dev/null 2>&1
    echo 'complete!'
    echo ''
    echo 'You can use the command "docker --version" check'
}

# 倒计时
countDown(){
    total=10
    if [ $1 ]; then
        total=$1
    fi
    i=0
    while [ "$i" -lt "$total" ];
    do
        echo -n "wait `expr $total - $i`s"
        sleep 1
        echo -ne "\r        \r"
        ((i++))
    done
}

# 接收参数
options=$(getopt -o chqsrv: --long check,help,quiet,remove,show,version: -n "error" -- "$@")

# 检测参数是否正确
if [ $? -ne 0 ]; then
    exit 0
fi

eval set -- "${options}"

version=
exist_version=
remove=0
quiet=0

while true
do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -c|--check)
            check
            exit 0
            ;;
        -q|--quiet)
            quiet=1
            shift 2
            ;;
        -r|--remove)
            remove=1
            shift 1
            ;;
        -s|--show)
            show
            exit 0
            ;;
        -v|--version)
            version=$2
            shift 2
            ;;
        *)
        break
        ;;
    esac
done

show > /dev/null

check

# 检查选择的版本是否正确
if [ "$version" ]; then
    echo -e "$registries" | awk '{print $2}' | grep -E "^$version\$" > /dev/null
    if [ $? -eq 1 ]; then
        echo "Selected docker version error"
        echo "You can get help information by useing -h or --help"
        echo "Version list:"
        echo -e "$registries" | sed  's/docker/     docker/'
        exit 1
    fi
fi

if [ -n "$exist_version" -a "$remove" -ne 1 ]; then
    echo ""
    echo "Docker already install"
    echo "Docker version: $exist_version"
    echo "You can use '-r' or '--remove' to force the delete"
    exit 0
fi

countDown 5

install "$version"
