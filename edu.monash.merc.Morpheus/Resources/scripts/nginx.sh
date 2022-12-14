#!/bin/bash -xe

# Wait for apt lock to be released
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
  sleep 10
done

apt-get -yq install nginx

cat << EOF > /etc/nginx/sites-enabled/default
server {
  listen 80 default_server;
  server_name _;

  location / {
    proxy_pass http://localhost:8888;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header Host \$http_host;
    proxy_http_version 1.1;
    proxy_redirect off;
    proxy_buffering off;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 86400;
  }
}
EOF

systemctl enable nginx
systemctl restart nginx
