#!/bin/bash

sudo mkdir -p /var/www/blog
sudo git clone https://github.com/jstnmthw/next-static-blog.git /var/www/blog
sudo chmod -R 755 /var/www/blog
cd /var/www/blog

# Run first time npm install setup on nextjs container
sudo docker-compose run --rm nextjs npm install
sudo docker-compose up -d
sudo docker-compose up certbot -d