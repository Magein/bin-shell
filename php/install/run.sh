#!/bin/sh

script_pwd=$PWD
version=7.1.13
package=tar.xz
prefix=
check=false
work_dir=
install=false
timer=on

usage(){
    echo "Usage:"
    echo "  run -version 5.6.35 --package tar.zx"
    echo "  run -home php-5.6.35"
    echo "Options:"
    echo "  -c,--check                      Check installation environment"
    echo "  -h,--help                       Show information for help"
    echo "  -y                              Install"
    echo "  -w,--work-dir                   Script work environment,default ~/php-7.1.13"
    echo "  -v,--version                    PHP installation version,default 7.1.13"
    echo "  --package                       Download packed format,default tar.xz"
    echo "  --prefix                        PHP installation location,default /usr/local/"
    echo "  --timer                         On or off timer,default on"
}

options=$(getopt -o ,c,h,y,v:,w: --long help,version:,package:,prefix:,work-dir:,timer: -n "error" -- "$@")

if [ $? -ne 0 ]; then
    exit 1
fi

eval set -- "${options}"

while true;
do
    case $1 in
        -c|--check)
            check=true
            shift 1
        ;;
        -h|--help)
            usage
            exit 0
        ;;
        -y)
            install=true
            shift 1
        ;;
        -v|--version)
            version=$2
            shift 2
        ;;
        -w|--work-dir)
            work_dir=$2
            shift 2
        ;;
        --package)
            package=$2
            shift 2
        ;;
        --prefix)
            prefix=$2
            shift 2
        ;;
        --timer)
            timer=$2
            shift 2
        ;;
        *)
            break
        ;;
    esac
done

if [ ! "$work_dir" ]; then
    work_dir="$HOME/php-$version/"
fi

if [ ! -f "$work_dir" ]; then
    mkdir -p "$work_dir"
    if [ $? -ne 0 ]; then
        echo " mkdir $work_dir error"
        exit 1
    fi
fi

cd "$work_dir"

log=$(mktemp)
name="php-$version"
package_name="php-$version.$package"
mirror="http://cn2.php.net/get/$package_name/from/this/mirror"

if [ ! "$prefix" ]; then
    prefix="/usr/local/$name"
fi

sha_256=
sha_256_file="$script_pwd/sha256"

gpg_key=
gpg_key_file="$script_pwd/gpg_keys"

asc_name="$package_name.asc"
asc_mirror="http://cn2.php.net/get/$asc_name/from/this/mirror"

commands=(
            curl
            wget
            tar
            sha256sum
            gpg
            yum
            make
            rpm
        )
# 支持的扩展
extensions=(
            --prefix="$prefix"
            --enable-fpm
            --enable-mysqlnd
            --enable-mbstring
            --disable-cgi
            --with-openssl
            --with-curl
            --with-gd
            --with-jpeg-dir
            --with-png-dir
            --with-zlib-dir
            --with-freetype-dir
          )
# 需要的依赖
dependents=(
            gcc
            libxml2-devel
            zlib-devel
            bison-devel
           )

# 所需要的权限
user_auth=(
            /usr/bin/yum
            /usr/bin/make
          )

# 重复指定字符串
# --string +      重复+字符串，默认空格
# --length 10     重复10次数，默认10次
# $repeat_return_result 结果
# example:
#   string_repeat string + length 5
#   echo "$repeat_return_result"
#   //输出：+++++
string_repeat(){

    repeat_return_result=
    repeat_string=" "
    repeat_length=10

    for param in "$@";
    do
        case "$param" in
            --string)
            repeat_string=$2
            shift 2
            ;;
            --length)
            repeat_length=$2
            ;;
        esac
    done
    
    if [ "$repeat_length" -lt 0 ]; then
        return 0
    fi
    
    if [ -z "$repeat_string" ]; then
        return 0
    fi

    i=0
    while [ "$i" -lt "$repeat_length" ];
    do
        repeat_return_result="$repeat_return_result$repeat_string"
        i=`expr "$i" + 1`
    done

    return 0
}

# 计时器
timer_start(){

    if [ "$timer" = "off" ]; then
        exec $* > "$log" 2>&1
        return 0
    else
        exec $* > "$log" 2>&1 &
    fi

    second=1
    echo ""
    while true;
    do
        spend="  Waiting seconds : ${second}s"
        echo -n "$spend"

        # 显示进程中的任务，没有则停止计时
        jobs=$(jobs -r)
        if [ -z "$jobs" ]; then
            echo -e "\n"
            break
        fi

        sleep 1
        clear_length="${#spend}"
        string_repeat "$clear_length"
        echo -en "\r$repeat_return_result\r"
        second=`expr "$second" + 1`
    done
}

# 输出分隔符
# 每一步之间的分隔符，用于提示进行到哪一步
segmentation(){
    string_repeat --string "#" --length 65
    echo ""
    echo "$repeat_return_result"
    echo ""
    echo -e $1
}

# 输出完成标志
Complete(){
    echo "  Complete!"
}

# 格式化输出
# --result        检测结果  true or false  unknow 未识别的值
# --option        检测的项
# --indent        缩进长度
format_print_check_result(){

    check_result=true
    indent_length=6
    print_string=

    for param in "$@";
    do
        case "$param" in
            --option)
            print_string=$2
            shift 2
            ;;
            --result)
            check_result=$2
            shift 2
            ;;
            --indent)
            indent_length=$2
            shift 2
            ;;
        esac
    done
    
    if [[ "$check_result" != true && "$check_result" != false ]]; then
        check_result="unknow"
    fi
    
    if [ "$indent_length" -lt 0 ]; then
        indent_length=0
    fi

    string_repeat --length "$indent_length"
    # 缩进的长度
    indent_string="$repeat_return_result"

    # 冒号前的总长度
    fixed_length=20
    # 检测项长度
    print_string_length="${#print_string}"

    # 计算需要追加的空格长度
    if [ "$fixed_length" -gt "$print_string_length" ]; then
        append_length=`expr "$fixed_length" - "$print_string_length"`
    else
        append_length="$fixed_length"
    fi

    string_repeat --length "$append_length"

    echo "$indent_string$print_string$repeat_return_result:         $check_result"
}

# 检测通过
check_pass(){
    format_print_check_result --option $1 --indent 6
}

# 检测不通过
# 检测不通过的选项记录
not_pass_options=
check_not_pass(){
    not_pass_options=$1
    format_print_check_result --option $1 --indent 6 --result false
}

# 检测用户权限
# 用户安装服务需要yum make 权限
# sudo默认五分钟有效时间，下载，编译，安装需要大约20分钟
check_user_auth(){
    allow=true
    for i in "${user_auth[@]}";
    do
        sudo -l | grep "$i" > /dev/null
        if [ $? -ne 0 ]; then
            check_not_pass "$i"
            allow=false
        else
            check_pass "$i"
        fi
    done

    if [ "$allow" = false ]; then
        echo "  Your identity does not have the installation conditions"
        exit 1
    fi

    timestamp_timeout=$(sudo -l | sed -r 's/.*?(timestamp_timeout=[0-9]*).*?/\1/g' | grep "timestamp_timeout" | awk -F= '{print $2}')

    if [[ -z "$timestamp_timeout" || "$timestamp_timeout" -lt 20 ]]; then
        echo "The whole process takes about 20-30 minutes"
        echo "So,sudo param of timestamp_timeout should more then 20 minutes"
        echo "  visudo append :Defaults    env_reset,timestamp_timeout=30"
        exit 1
    fi
}

# 检测用户身份
# 非root用户需要检验用户权限
# 需要sudo yum，make权限，并且sudo有效时间应该大于20分钟
check_user_identity(){
    segmentation "Check the identity of the user"
    user=$(whoami)
    echo "  user : $user"
    if  [ "$user" = "root" ]; then
        for i in "${user_auth[@]}";
        do
            check_pass "$i"
        done
    else
        check_user_auth
    fi
}

# 获取php安装扩展的依赖
extension_dependents(){
    length="${#extensions[*]}"
    for i in "${extensions[@]}";
    do
        length=`expr "$length" + 1`
        case "$i" in
            --with-curl)
            dependents[$length]="libcurl-devel"
            ;;
            --with-openssl)
            dependents[$length]="openssl-devel"
            ;;
            --with-gd)
            dependents[$length]="gd-devel"
            ;;
            --with-jpeg-dir|--with-png-dir)
            dependents[$length]="libpng-devel"
            ;;
            --with-freetype-dir)
            dependents[$length]="freetype-devel"
            ;;
        esac
    done
}

# 检测环境
# 系统要求是centos
check_environment(){

    segmentation 'Check install environment'

    echo "  OS:"
    if [ -f "/etc/redhat-release" ]; then
        check_pass "CentOS"
    else
        check_not_pass "CentOS"
    fi

    echo "  commands:"
    for i in "${commands[@]}";
    do
        if [ -f "/usr/bin/$i" ]; then
            check_pass "$i"
        else
            check_not_pass "$i"
        fi
    done

    extension_dependents
    echo "  dependents:"
    for i in "${dependents[@]}";
    do
        dependent=$(rpm -qa "$i")
        if [ -z "$dependent" ]; then
            check_not_pass "$i"
        else
            check_pass "$i"
        fi
    done
}

# 获取sha256以便于验证文件完整性
# 从三个地方获取sha256
# 1. 从本地文件中获取
# 2. 从下载页面获取(http://php.net/downloads.php)
# 3. 从历史归档中获取(http://php.net/releases/)
# 假如官方下载页面提供的版本是php-5.6.36，要安装php-5.6.35，就需要从归档页面中获取
get_sha_256(){

    segmentation "Find $package_name sha256"
    
    if [ ! "$sha_256" ]; then
        is_write=false
        if [ -f "$sha_256_file" ]; then
            sha_256=$(cat "$sha_256_file" | grep "$package_name" | awk '{print $2}')
        else
            touch "$sha_256_file"
        fi

        # 从官方下载页面中获取sha256的值
        if [ ! "$sha_256" ]; then
            is_write=true
            sha_256=$(curl -s  http://php.net/downloads.php |sed -n "/$package_name/,/sha256/p" | grep sha256 | sed -e 's/ //g' -e 's/<spanclass="sha256">//' -e 's/<\/span><\/li>//')
        fi

        # 从历史归档中获取sha256的值
        if [ ! "$sha_256" ]; then
            is_write=true
            sha_256=$(curl -s http://php.net/releases/ | sed -n "/$version ($package)/,/sha256/p" | grep sha | awk '{print $3}' | sed 's/<\/span>//')
        fi

        if [ ! "$sha_256" ]; then
            check_not_pass SHA256
            return 1
        fi

        if [ "$is_write" = "true" ]; then
            echo "$package_name $sha_256" >> "$sha_256_file"
        fi
    fi
    echo "      Complete!"
    echo "      $sha_256"

    return 0
}

get_gpg_keys(){

    segmentation "Find $package_name gpg keys"

    if [ -z "$gpg_key" ]; then

        keys=$(echo "$version" | awk 'BEGIN{FS=".";OFS="."}{print$1,$2}')

        # 从文件中获取
        is_write=false
        if [ -f "$gpg_key_file" ]; then
            gpg_key=$(grep "php-$keys.*" "$gpg_key_file" | awk '{$1="";print$0}' | sed 's/ //')
        else
            touch "$gpg_key_file"
        fi

        # 从php官网获取
        if [ -z "$gpg_key" ]; then
            is_write=true
            gpg_key=$(curl -s http://php.net/downloads.php | sed -n "/id=\"gpg-$keys\"/,/<\/pre>/p" | grep 'Key fingerprint' | sed 's/Key fingerprint =//' | sed 's/ //g')
        fi

        if [ ! "$gpg_key" ]; then
            check_not_pass "GPG KEYS"
            return 1
        fi

        if [ "$is_write" = "true" ]; then
            gpg_key_array=("$gpg_key")
            gpg_key=
            for i in ${gpg_key_array[@]};
            do
                if [ -z "$gpg_key" ]; then
                    gpg_key="$i"
                else
                    gpg_key="$gpg_key $i"
                fi
            done
            echo -n "php-$keys.* $gpg_key" >> "$gpg_key_file"
        fi
    fi

    echo "      Complete!"
    echo "      $gpg_key"

    return 0
}

# 下载php安装包
get_php_package(){

    segmentation "Download $package_name"

    if [ ! -f "$package_name" ]; then
        timer_start wget -O "$package_name" "$mirror"
    fi

     Complete

     return 0
}

# 导入秘钥
import_gpg_key(){

    export GNUPGHOME=$(mktemp -d)

    for key in "$@";
    do
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" > /dev/null 2>&1
    done

    return 0
}

# 检查php包
check_package(){

    segmentation "Check SHA256 and GPG for $package_name"
    
    if [ ! "$sha_256" ]; then
        echo "  sha256 is empty or $package_name not found"
        exit 1
    fi
    
    if [ ! "$gpg_key" ]; then
        echo "  GPG keys not found"
        exit 1
    fi

    echo "$sha_256 *$package_name" | sha256sum -c - > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        check_pass SHA256
    else
        check_not_pass SHA256
    fi

    gpg_key=(${gpg_key})
    import_gpg_key ${gpg_key[@]}

    if [ ! -f "$asc_name" ]; then
        wget "$asc_mirror" -O "$asc_name" > /dev/null 2>&1
    fi

    gpg --batch --verify "$asc_name" "$package_name" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        check_pass GPG
        return 0
    else
        check_not_pass GPG
        exit 1
    fi
}

# 解压php包
unzip_package(){

    segmentation "Unzip $package_name"

    if [ ! -f "$package_name" ];then
        echo "  $package_name not found"
        exit 1
    fi

    if [ -d "$name" ]; then
        Complete
        return 0
    fi

    mkdir -p "$name"

    # 获取压缩包格式
    packed_format=$(echo "$package_name" | awk -F. '{print $5}')
    options=
    case "$packed_format" in
        xz)
        options='J'
        break
        ;;
        bz2)
        options='j'
        break
        ;;
    esac

    options="${options}xf"

    timer_start tar "-$options" "$package_name" -C "$name" --strip-components=1

    if  [ $? -eq 0 ]; then
        Complete
    fi

    return 0
}

# 安装依赖
install_dependents(){

    segmentation "Start installation dependents"

    timer_start sudo yum -y install "${dependents[@]}"

    Complete
}

# 权限不足输出信息
permission_denied(){

    if [ -f "$1" ]; then
        error=$(cat "$1")
    else
        error=$1
    fi

    permission=$(echo "$error" | grep -E "configure: error: write failure creating ./config.status|Permission denied" )
    if [ -n "$permission" ]; then
        echo ""
        echo "  $permission"
        echo "  You can use root identity,or"
        echo "  You can use the following command as a super administrator"
        ways=(
            "sudo (Recommend)"
            "setfacl -m u:xxx:rwx"
            "chown $(whoami) /{path}"
            "chgrp $(whoami) /{path}"
            "chgrp new_group /{path},then usermod -G new_group"
        )

        number=1
        for way in "${ways[@]}";
        do
            echo "      $number. $way"
            number=`expr "$number" + 1`
        done
        exit 0
    else
        configure_error=$(echo "$error" | grep "configure: error:")
        if [ -n "$configure_error" ]; then
            echo "$configure_error"
            exit 1
        fi
    fi

    return 0
}

# 编译安装
configure(){

    segmentation "Configure start,Please wait a moment"

    cd "$name"

    timer_start ./configure "${extensions[@]}"
    permission_denied "$log"

    echo "Make start,Please wait a moment"
    timer_start sudo make
    error=$(tail -n 2 "$log" | grep -E "Build complete.|Don't forget to run 'make test'.")
    if [ -z "$error" ]; then
        tail -n 5 "$log"
        exit 1
    fi

    echo "Make install,Please wait a moment"
    timer_start sudo make install
    permission_denied "$log"

    cd ..

    if [ -f "./php.ini" ]; then
        cp ./php.ini /usr/local/lib/
    else
        cp "$PWD/$name/php.ini-development" /usr/local/lib/php.ini
    fi

    echo -e "\n"
    segmentation "Install complete"
}

start_time=$(date +%s)

check_user_identity
check_environment
get_sha_256
get_gpg_keys

if [[ "$check" = "true" ||  "$install" = "false" ]]; then
    exit 0
fi

if [ "$not_pass_options" ]; then
    segmentation "  Unable to install, the following option is not passed"
    check_not_pass  "$not_pass_options"
    exit 0
fi

get_php_package
check_package
unzip_package
configure

end_time=$(date +%s)
spend_time=`expr "$end_time" - "$start_time"`
echo "Total spend : ${spend_time}s"

rm -rf "$log"


