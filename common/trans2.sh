#!/bin/sh

if [ ! -f /usr/bin/dos2unix ]; then
    sudo yum -y install dos2unix
fi

if [ -f $1 ]; then
  dos2unix -q $1
fi

eval $@