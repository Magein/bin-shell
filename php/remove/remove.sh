#!/bin/sh

# 直接删除可能会存在问题，建议谨慎使用，

# 删除/usr/local/lib/php目录和/usr/local/lib/php.ini文件
rm -rf /usr/local/lib/php*

# 删除 /usr/local/etc目录下的php文件
rm -rf /usr/local/etc/php*

# 删除 /usr/local/bin目录下的php文件
rm -rf /usr/local/bin/php*

# 删除 /usr/local/include目录下的php文件
rm -rf /usr/local/include/php*

# 删除 /usr/local/sbin/目录下的php文件
rm -rf /usr/local/sbin/php*