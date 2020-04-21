#!/bin/bash

OS="`uname`"
case $OS in
  'Linux')
    OS='Linux'
    hostnamectl |grep Operating|cut -d':' -f2   
#alias ls='ls --color=auto'
    ;;
  'FreeBSD')
    OS='FreeBSD'
    alias ls='ls -G'
    ;;
  'WindowsNT')
    OS='Windows'
    ;;
  'Darwin') 
    OS='Mac'
    ;;
  'SunOS')
    OS='Solaris'
    ;;
  'AIX') ;;
  *) ;;
esac
