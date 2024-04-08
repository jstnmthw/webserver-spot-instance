#!/bin/bash

sudo mkdir -p /var/www/blog
sudo git clone https://github.com/jstnmthw/next-static-blog.git /var/www/blog
sudo chmod -R 755 /var/www/blog
cd /var/www/blog

# Run first time npm install setup on nextjs container
sudo docker-compose run --rm nextjs npm install
sudo docker-compose up -d
sudo docker-compose up certbot -d

# #!/bin/bash

# # 1. Clone the repo
# git clone <repo_url>
# cd your_repo_directory

# # 2. Start Docker containers
# docker-compose up -d

# # 3. Run npm install in a specific container
# docker exec -it your_node_container npm install

# # 4. Run nginx container with challenge.conf
# docker run -d \
#   --name your_nginx_container \
#   -v /path/to/challenge.conf:/etc/nginx/conf.d/challenge.conf:ro \
#   -v /path/to/letsencrypt:/etc/letsencrypt \
#   your_nginx_image

# # 5. Run Certbot to issue SSL
# docker run -it --rm \
#   -v /path/to/letsencrypt:/etc/letsencrypt \
#   certbot/certbot certonly --nginx

# # Check if SSL issuance was successful
# if [ $? -eq 0 ]; then
#   # 6. Stop and remove the nginx container
#   docker stop your_nginx_container
#   docker rm your_nginx_container

#   # 7. Replace challenge.conf with prod.conf
#   mv /path/to/challenge.conf /path/to/prod.conf

#   # 8. Start nginx container with prod.conf
#   docker run -d \
#     --name your_nginx_container \
#     -v /path/to/prod.conf:/etc/nginx/conf.d/prod.conf:ro \
#     -v /path/to/letsencrypt:/etc/letsencrypt \
#     your_nginx_image
# else
#   echo "SSL issuance failed. Check Certbot logs."
# fi
