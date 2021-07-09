#!/bin/bash
sudo yum -y update

echo "Install Apache"
sudo yum -y install httpd

echo "Hello from ip - $(hostname -I)"  > /var/www/html/index.html

echo "Start Apache Server"
sudo service httpd start  
