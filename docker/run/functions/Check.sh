#!/bin/sh
# 总共需要检查以下项
#   检测docker
#       验证是否已经安装 docker
#       docker 版本需要大于17.x
#
#   需要启动 docker
#
#       使用docker images 或者 docker pull 需要事先启动docker
#
#   检测镜像是否已经拉取
#
#   验证配置文件目录是否拥有可写权限
#

# 返回值
#   遵循linux 返回值标准
#   0 正常
#   1 异常
#

#
# 检测 docker 是否已经安装
#   提示版本应该大于17
# 如果没有安装也返回 false
#
CheckVersion(){
    if  [ -f /usr/bin/docker ]; then
        return 0
    fi
    return 1
}

# 检测docker是否已经启动
# 拉取镜像、验证镜像是否存在需要启动docker才行
#   docker images
#   docker pull
#
CheckStatus(){
    systemctl status docker | grep "Active: active (running)" > /dev/null 2>&1
    return $?
}

# 检测镜像是否已经 pull
# 参数不存在或者没有拉取返回 false
CheckImage(){
    if [ -z "$1" ]; then
        return 1
    fi
    docker images | grep -w "$1" > /dev/null 2>&1
    return $?
}

# 验证目录是否有可写权限
# 创建一个临时文件进行确认
CheckDirectoryWriteAuth(){
    if [ -z "$1" ]; then
        return 1
    fi
    if [ -d "$1" ]; then
       temp_file=$(mktemp -p $1)
       if [ $? -eq 0 ]; then
           rm -rf "$temp_file"
           return 0
       fi
       return 1
    fi
    return 1
}

# 检测结果
# 传递参数则追加
# 不传递则输出结果
CheckPass=()
CheckPass(){
    if [ "$1" ]; then
        length="${#CheckPass[@]}"
        CheckPass[$length]="$1"
        return 0
    fi

    for result in "${CheckPass[@]}";
    do
        echo "$result"
    done
}

CheckFail=()
CheckFail(){
    if [ "$1" ]; then
        length="${#CheckFail[@]}"
        CheckFail[$length]="$1"
        return 0
    fi

    for result in "${CheckFail[@]}";
    do
        echo "$result"
    done
}

# 检测运行环境
Check(){
    CheckVersion
    if [ $? -eq 0 ]; then
        version=`docker -v | awk '{print $3}' | awk -F. '{print $1}'`
        CheckPass "Docker Version :    true ( $version ) "
    else
        CheckFail "Docker Version :    false ( please install docker )"
    fi

    CheckStatus
    if [ $? -eq 0 ]; then
        CheckPass "Docker Status :    true( running )"
    else
        CheckFail "Docker Status :    false( dead )"
    fi

    # 检测目录写权限
    for directory in "$@";
    do
        CheckDirectoryWriteAuth "$directory"
        if [ $? -eq 0 ]; then
            CheckPass "$directory :    true ( write )"
        else
            CheckFail "$directory :    false ( do not write )"
        fi
    done

    CheckPass
    CheckFail
}

