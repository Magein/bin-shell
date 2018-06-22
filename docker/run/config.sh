#!/bin/sh

segmentation(){
    echo ""
    echo "#################################################################"
    echo ""
    echo -e $1
    
    if [ $2 ]; then
        echo "Storage location:" $2
    fi
}

ini(){
    {
        echo "[php]"
        echo "display_errors = On"
    } | tee "$1" > /dev/null

    segmentation "Create php.ini file complete" $1
}

fpm(){
    {
        echo "[global]"
        echo "pid = run/php-fpm.pid"
        echo "error_log = log/php-fpm.log"
        echo "daemonize = no"
        echo "include=/usr/local/etc/php-fpm.d/*.conf"
    } | tee "$1" > /dev/null

    segmentation "Create php-fpm.conf file complete" $1
}

pool(){
    {
        echo "[www]"
        echo "user = nobody"
        echo "group = nobody"
        echo "listen = [::]:9000"
        echo "pm = dynamic"
        echo "pm.max_children = 5"
        echo "pm.start_servers = 2"
        echo "pm.min_spare_servers = 1"
        echo "pm.max_spare_servers = 3"
    } | tee "$1" > /dev/null

    segmentation "Create pool.conf file complete" $1
}

nginx(){

    root="html"

    {
        echo "worker_processes  1;
        events{
            worker_connections  1024;
        }
        http{

            include       mime.types;

            default_type  application/octet-stream;

            sendfile        on;

            keepalive_timeout  65;

            server{

                listen       80;

                server_name  localhost;

                location /
                {
                    root   $root;
                    index  index.html;
                }

                error_page  404             /404.html;
                location = /404.html
                {
                    root   $root;
                }

                error_page   500 502 503 504  /50x.html;
                location = /50x.html
                {
                    root   $root;
                }

                location ~ \.php$
                {
                    fastcgi_pass   php:9000;
                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
                    include        fastcgi_params;
                }
            }
        }"

    } | tee "$1"  > /dev/null

    segmentation "Create nginx.conf file complete" $1
}