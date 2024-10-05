#!/bin/bash
sudo yum update -y
sudo yum install -y nfs-utils amazon-efs-utils

sudo mkdir -p /mnt/efs
sudo mount -t efs fs-0bee2a3ca8b069311.efs.us-east-1.amazonaws.com:/ /mnt/efs

sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

DOCKER_COMPOSE_VERSION="1.29.2"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

docker-compose --version

sudo mkdir -p /home/ec2-user/wordpress
sudo chown ec2-user:ec2-user /home/ec2-user/wordpress

cat <<EOF > /home/ec2-user/wordpress/docker-compose.yml
version: '3.8'
 
services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    restart: always
    ports:
      - "80:80"  
    environment:
      WORDPRESS_DB_HOST: "projeto-2-compass-rds.cngyqmcsamml.us-east-1.rds.amazonaws.com"
      WORDPRESS_DB_USER: "wordpress"
      WORDPRESS_DB_PASSWORD: "wordpress"
      WORDPRESS_DB_NAME: "wordpress" 
      TZ: "America/Sao_Paulo"  
    volumes:
      - /mnt/efs:/var/www/html  
    networks:
      - wp-network
 
networks:
  wp-network:
    driver: bridge
 
volumes:
  db_data:
EOF

cd /home/ec2-user/wordpress
docker-compose up -d
