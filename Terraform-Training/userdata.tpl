#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello World! Congratulations on setting up your first WebServer!</h1>" > var/www/html/index.html
