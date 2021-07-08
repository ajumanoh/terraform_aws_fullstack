#!/bin/bash
sudo yum -y update

echo "Install Apache"
sudo yum -y install httpd

echo "Start Apache Server"
sudo service httpd start  

echo "Hello from ip - $(hostname -f)"  > /var/www/html/index.html
