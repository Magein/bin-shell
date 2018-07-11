#!/bin/sh
# 创建目录
MakeDirectory(){
    for directory in "$@";
    do
        if [ ! -d "$directory" ];then
            mkdir -p "$directory"
            if [ $? -eq 1 ]; then
                echo "You can use root to create"
                echo "  then:"
                echo "      chgrp docker $directory"
                echo "      chmod 2775 $directory"
                echo "Or,use setfacl -m g:docker:rwx $directory"
                exit 1
            fi
            chgrp docker "$directory"
            chmod 2775 $directory
        fi
    done
}

# 创建文件
MakeFile(){
     for name in "$@";
        do
            if [ ! -f "$name" ];then
                touch "$name"
                if [ $? -eq 1 ]; then
                    exit 0
                fi
            fi
    done
}