#!/bin/sh

version=
exist_version=
check_result=()

old=(\
    docker \
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

dependent=(\
    yum-utils \
    device-mapper-persistent-data \
    lvm2
    )

# 显示帮助信息
Usage(){
    echo "Usage:"
    echo "  start [options]"
    echo "  start -o --version 17.09.0.ce-1.el7.centos"
    echo "Options:"
    echo "  -c, --check              Check install environment"
    echo "  -h, --help               Show information for help"
    echo "  -r, --remove             Remove docker"
    echo "  -s, --show               Display the docker version of the optional installation"
    echo "  -v, --version            The version of the docker to install"
}

Segmentation(){
    echo ""
    echo "============================================================================="
    echo ""
    echo "$1"
}

Complete(){
    echo " Complete";
}

# 检测结果
# 如果传递了参数，则记录这次检测的结果
# 如果没有传递参数，则验证最总的检测结果是否存在false的情况
CheckResult(){
    if [ "$1" ]; then
        result="true"
        if [ $2 ]; then
            result=$2
        fi
        echo "$1:                $result"
        length="${#check_result[*]}"
        key=`expr "$length" + 1 `
        check_result[$key]="$result";
        return 0
    else
        for i in "${check_result[@]}";
        do
          if [ "$i" = false ]; then
              Segmentation "please view check result"
              exit 0
          fi
        done
    fi
}

CheckOS(){
    System=true
    # 检测是否为centOS系统
    if [ ! -f "/etc/redhat-release" ]; then
        System=false
    fi
    CheckResult "CentOS System" "$System"

    # 检测内核版本
    kernel=$(uname -r | awk -F. '{print $1}')
    if [ "$kernel" -lt 3 ]; then
        Kernel=false
    else
        Kernel=true
    fi
    CheckResult "Kernel version" "$Kernel"
}

CheckUser(){
    # 如果不是root用户，则检查是否拥有sudo，yum权限
    uid=`id -u`
    if [ "$uid" -ne 0 ]; then
        # 检查是否有用 sudo 权限
        sudo -nl >> /dev/null 2>&1
        result=$?
        Sudo=false
        if [ "$result" -eq 0 ];then
            Sudo=true
        fi
        CheckResult "Sudo permission" "$Sudo"

        # 如果拥有sudo权限，则验证是有有yum权限
        Yum=false
        sudo -l | grep /usr/bin/yum > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            Yum="true"
        fi
        CheckResult "Yum permission" "$Yum"

        manager=false
        if [ "$Yum" = true ]; then
            sudo -l | grep /usr/bin/yum-config-manager > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                manager="true"
            fi
        fi
        CheckResult "Config manager permission" "$manager"
    fi
}

CheckYumConfigManager(){
    if [ ! -f "/usr/bin/yum-config-manager" ]; then
         CheckResult "Config manager permission" "$manager"
    fi
}

# 检测系统环境
Check(){
    CheckOS
    CheckUser
    CheckYumConfigManager
    return 0
}

# 检查是否有 docker-ce.repo
CheckDockerRepo(){
    if [ ! -f "/etc/yum.repos.d/docker-ce.repo" ]; then
        Segmentation "error"
        echo "Please add  docker-ce.repo"
        echo "Use root : yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
        exit 0
    fi
}

# 安装yum-config-manager
InstallConfigManager(){
    if [ ! -f "/usr/bin/yum-config-manager" ]; then
        echo 'Start installed yum-config-manager'
        sudo yum -y install "${dependent[@]}" > /dev/null 2>&1
        echo 'Complete!!!!'
    fi
}

# 显示可选的docker版本
# 使用此方法必须安装 docker-ce.repo
Show(){
    Check
    CheckResult
    CheckDockerRepo
    registries=$(yum list docker-ce --showduplicates | sort -r | grep docker-ce)
    echo -e "$registries"
}

# 移除
Remove(){
    Check
    CheckResult
    sudo yum -y remove "${old[@]}" > /dev/null 2>&1
    Complete
}

# 安装docker
Install(){
    if [ -z $1 ]; then
        version=`"$registries" | awk 'NR==1{print $2}'`
    else
        version=$1
    fi
    sudo yum -y install docker-ce-"$version"
    echo 'complete!'
    echo ''
    echo 'You can use the command "docker --version" check'
}

# 倒计时
CountDown(){
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

while true
do
    case $1 in
        -h|--help)
            Usage
            exit 0
            ;;
        -c|--check)
            Check
            exit 0
            ;;
        -q|--quiet)
            quiet=1
            shift 2
            ;;
        -r|--remove)
            Remove
            exit 0
            ;;
        -s|--show)
            Show
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

# 检查安装环境是否符合条件
Check
CheckResult

InstallConfigManager

# 检查选择的版本是否正确
if [ "$version" ]; then
    Show > /dev/null
    echo -e "$registries" | awk '{print $2}' | grep -E "^$version\$" > /dev/null
    if [ $? -eq 1 ]; then
        echo "Selected docker version error"
        echo "You can get help information by useing -h or --help"
        echo "Version list:"
        echo -e "$registries" | sed  's/docker/     docker/'
        exit 1
    fi
else
    echo "Please choose docker-ce version"
    echo "You can get version of use -s"
    exit 0
fi

if [ -n "$exist_version" ]; then
    echo ""
    echo "Docker already install"
    echo "Docker version: $exist_version"
    echo "You can use '-r' or '--remove' to force the delete"
    exit 0
fi

CountDown 5

Install                                                                                                                                                                 "$version"