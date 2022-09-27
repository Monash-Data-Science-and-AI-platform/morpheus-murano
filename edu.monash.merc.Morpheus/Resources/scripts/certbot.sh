#!/bin/bash -xe

# Wait for apt lock to be released
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
  sleep 10
done

apt-get -yq install certbot python3-certbot-nginx

FQDN="$1"
EMAIL="$2"

NGINX_CFG=/etc/nginx/nginx.conf
NGINX_VHOST_CFG=/etc/nginx/sites-enabled/default
LETS_ENCRYPT_LIVE="/etc/letsencrypt/live"
KEY="${LETS_ENCRYPT_LIVE}/${FQDN}/privkey.pem"
CRT="${LETS_ENCRYPT_LIVE}/${FQDN}/cert.pem"

# use test cert option when testing package
CERTBOT_ARGS=""
#CERTBOT_ARGS="--test-cert"

# change nginx server_name from _ to fqdn
sed -i 's/^\([ \t]\+server_name[ \t]\+\)_\([ \t]*;[ \t]*\)$/\1'$FQDN'\2/' $NGINX_VHOST_CFG

# allow for long fqdns (> 47 chars) otherwise nginx gives the error
# could not build server_names_hash
sed -i 's/^\([ \t]\+server_names_hash_bucket_size[ \t]\+\).*;$/\1128;/' $NGINX_CFG

# setup nginx let's encrypt certificate, redirect http to https, and enable auto renewal
certbot --nginx --agree-tos --no-eff-email --redirect -d "$FQDN" -m "$EMAIL" $CERTBOT_ARGS &> /dev/null

# display certificate fingerprint
openssl x509 -noout -fingerprint -sha256 -inform pem -in "$CRT"

# vim: ts=2 sw=2 :
