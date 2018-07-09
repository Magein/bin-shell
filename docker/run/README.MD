### 脚本说明
    
    config.sh  创建php.ini、php-fpm.conf、nginx.conf、www.conf配置文件，都是简写的配置文件
    run.sh   快速启动nginx+php容器
    
    下载后，如果在win下面编辑请使用dos2unix进行文件转化
    如：
        ls | xargs dos2unix
        
        ./run.sh
        
        
### 权限验证

    1. 默认配置文件路径 /usr/local/docker  docker目录是没有的，使用root身份直接创建，组修改为 docker组 把 用户加入到组中即可
     
        # 切换到root身份
        su root
     
        # 创建docker目录
        mkdir -p /usr/local/docker
         
        # 让目录的组成员有可写权限
        chmod g+w /usr/local/docker
         
        # 把xiaomage用户加入到docker组中
        # docker组在安装docker的时候已经存在，默认gid为994
        chgrp -a -G xiaomage docker
        
        附： 也可以通过 --conf 参数修改存放配置文件的位置
         
    2. 日志文件
     
        默认存放在 /var/log/nginx  /var/log/php
        
        所以当前用户需要有 /var/log 目录的可写权限
         
        又因为 /var/log是系统日志的目录 所以不建议直接修改目录的所有者以及所有组
         
        当然更不建议把当前非root用户直接加入到root组中，推荐使用acl权限去处理这个问题
        
        su root
        getfacl /var/log/
        setfacl -m g:docker:rwx /var/log/
        
        
        
    