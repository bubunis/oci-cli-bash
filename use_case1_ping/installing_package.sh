#!/bin/bash
set -e

YUM_PACKAGE_NAME="openssl*"
DEB_PACKAGE_NAME="python2.7 python-dev python-pip libssl-dev"

func_openssl_conf(){
    mkdir ~/.oci
    openssl genrsa -out ~/.oci/oci_api_key.pem 2048
    openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
    SIGN=`openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c|cut -d'=' -f2`
    echo $SIGN
}


 if cat /etc/*release | grep ^NAME | grep CentOS; then
    echo "==============================================="
    echo "Installing packages $YUM_PACKAGE_NAME on CentOS"
    echo "==============================================="
    yum install -y $YUM_PACKAGE_NAME
	func_openssl_conf
    
 elif cat /etc/*release | grep ^NAME | grep Red; then
    echo "==============================================="
    echo "Installing packages $YUM_PACKAGE_NAME on RedHat"
    echo "==============================================="
    yum install -y $YUM_PACKAGE_NAME
 elif cat /etc/*release | grep ^NAME | grep Fedora; then
    echo "================================================"
    echo "Installing packages $YUM_PACKAGE_NAME on Fedorea"
    echo "================================================"
    yum install -y $YUM_PACKAGE_NAME
 elif cat /etc/*release | grep ^NAME | grep Ubuntu; then
    echo "==============================================="
    echo "Installing packages $DEB_PACKAGE_NAME on Ubuntu"
    echo "==============================================="
    apt-get update
    apt-get install -y $DEB_PACKAGE_NAME
 elif cat /etc/*release | grep ^NAME | grep Debian ; then
    echo "==============================================="
    echo "Installing packages $DEB_PACKAGE_NAME on Debian"
    echo "==============================================="
    apt-get update
    apt-get install -y $DEB_PACKAGE_NAME
 elif cat /etc/*release | grep ^NAME | grep Mint ; then
    echo "============================================="
    echo "Installing packages $DEB_PACKAGE_NAME on Mint"
    echo "============================================="
    apt-get update
    apt-get install -y $DEB_PACKAGE_NAME
 elif cat /etc/*release | grep ^NAME | grep Knoppix ; then
    echo "================================================="
    echo "Installing packages $DEB_PACKAGE_NAME on Kanoppix"
    echo "================================================="
    apt-get update
    apt-get install -y $DEB_PACKAGE_NAME
 else
    echo "OS NOT DETECTED, couldn't install package $PACKAGE"
    exit 1;
 fi

exit 0
