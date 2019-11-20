#!/bin/bash

echo ""
echo "----------------------------------"
echo "Clapp_project Ex-potato"
echo "Mastodon3 Installer"
echo "----------------------------------"

ask_basic_info_recursively(){
  echo
  echo -n "マストドンのドメイン名: "
  read DOMAIN
  echo -n "SSL証明書の更新通知先メールアドレス: "
  read MADDR
 echo -n "MastodonのGitリポジトリ"
  read GIT
  echo "【設定】"
  echo "  ドメイン: "$DOMAIN
  echo "  メール　: "$MADDR
  echo "  Gitリポジトリ:" $GIT
  echo -n "上記内容でインストールしますか？ (y/n/q): "
  read install_answer
  case $install_answer in
    y)
      return 0
      ;;
    q)
      echo "インストールをキャンセルしました."
      exit
      ;;
    *)
      echo "不正な入力です。もう一度入力してください。"
      ask_basic_info_recursively
      ;;
  esac
}

ask_basic_info_recursively

set -x
echo "インストールの準備をしています...."

yum install -y || exit1
yum-config-manager --enable epel
yum install -y http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm || exit 1
curl -sL https://rpm.nodesource.com/setup_8.x | bash -
echo "パッケージをインストールしています..."
sleep 10s
yum update -y || exit1
yum install -y ImageMagick ffmpeg redis rubygem-redis postgresql-96-{serve,contrib,devel} authd nodejs{openssl,redline,zlib,libxml2,libxslt,protobuf,ffmpeg,libidn,libicu}-devel protobuf-compiler nginx jq bind-utils || exit 1
npm install -g yarn || exit 1

export PGSETUP_INITDB_OPTIONS="--encoding=UTF-8 --no-locale"
/usr/pgsql-9.6/bin/postgresql96-setup initdb
sed -i "s/ident/trust/" /var/lib/pgsql/9.6/data/pg_hba.conf
systemctl enable postgresql-9.6 redis
systemctl start postgresql-9.6 redis
su - postgres -c "createuser --createdb mastodon"

#ruby, mastodon
useradd mastodon
SETUP=/home/mastodon/setup.sh
cat <<_EOF_ >${SETUP}
REPO=https://github.com/sstephenson
git clone \${REPO}/rbenv.git ~/.rbenv
echo 'export PATH="~/.rbenv/bin:/usr/pgsql-9.6/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
rbenv init - >> ~/.bash_profile
source ~/.bash_profile
git clone \${REPO}/ruby-build.git ~/.rbenv/plugins/ruby-build
git clone \${GIT} live
cd live
git checkout \$(git tag|grep -v rc|tail -1)
cd ..
RV=\$(cat live/.ruby-version)
rbenv install \${RV}
rbenv global \${RV}
rbenv rehash
cd live
gem install bundler -v 1.16.1
bundle install --deployment --without development test
yarn install --pure-lockfile
cp .env.production{.sample,}
export RAILS_ENV=production SAFETY_ASSURED=1
SKB=\$(bundle exec rake secret)
PS=\$(bundle exec rake secret)
OS=\$(bundle exec rake secret)
sed -i -e "s/_HOST=[rd].*/_HOST=localhost/" \
-e "s/=postgres$/=mastodon/" \
-e "s/^LOCAL_DOMAIN.*/LOCAL_DOMAIN=${DOMAIN}/" \
-e "s/^LOCAL_HTTPS.*/LOCAL_HTTPS=true/" \
-e "s/^SMTP_SERVER.*/SMTP_SERVER=localhost/" \
-e "s/^SMTP_PORT=587/SMTP_PORT=25/" \
-e "s/^SMTP_LOGIN/#SMTP_LOGIN/" \
-e "s/^SMTP_PASSWORD/#SMTP_PASSWORD/" \
-e "s/^#SMTP_AUTH_METHOD.*/SMTP_AUTH_METHOD=none/" \
-e "s/^SMTP_FROM_ADDRESS.*/SMTP_FROM_ADDRESS=${MADDR}/" \
-e "s/^SECRET_KEY_BASE=/SECRET_KEY_BASE=\${SKB}/" \
-e "s/^OTP_SECRET=/OTP_SECRET=\${OS}/" .env.production
export \$(bundle exec rake mastodon:webpush:generate_vapid_key)
sed -i -e "s/^VAPID_PRIVATE_KEY=/VAPID_PRIVATE_KEY=\${VAPID_PRIVATE_KEY}/" \
-e "s/^VAPID_PUBLIC_KEY=/VAPID_PUBLIC_KEY=\${VAPID_PUBLIC_KEY}/" .env.production
bundle exec rails db:setup
bundle exec rails assets:precompile
_EOF_

chmod 755 ${SETUP}
chown mastodon. ${SETUP}
su - mastodon -c "/bin/bash ${SETUP}"

SDIR=/etc/systemd/system
cat <<"_EOF_" >${SDIR}/mastodon-web.service
[Unit]
Description=mastodon-web
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/live
Environment="RAILS_ENV=production"
Environment="PORT=3000"
ExecStart=/home/mastodon/.rbenv/shims/bundle exec puma -C config/puma.rb
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
_EOF_

cat <<"_EOF_" >${SDIR}/mastodon-sidekiq.service
[Unit]
Description=mastodon-sidekiq
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/live
Environment="RAILS_ENV=production"
Environment="DB_POOL=5"
ExecStart=/home/mastodon/.rbenv/shims/bundle exec sidekiq -c 5 -q default -q mailers -q pull -q push
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
_EOF_

cat <<"_EOF_" >${SDIR}/mastodon-streaming.service
[Unit]
Description=mastodon-streaming
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/live
Environment="NODE_ENV=production"
Environment="PORT=4000"
ExecStart=/usr/bin/npm run start
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
_EOF_
systemctl enable mastodon-{web,sidekiq,streaming}

#nginx
sed -i -e 's/user nginx/user mastodon/' -e '1,/location/s/location \/ {/location ^~ \/.well-known\/acme-challenge\/ {}\n\tlocation \/ {\n\t\treturn 301 https:\/\/$host$request_uri;/' /etc/nginx/nginx.conf
chown -R mastodon. /var/{lib,log}/nginx
sed -i 's/ nginx nginx/ mastodon mastodon/' /etc/logrotate.d/nginx

LD=/etc/letsencrypt/live/${DOMAIN}
CERT=${LD}/fullchain.pem
PKEY=${LD}/privkey.pem

cat <<_EOF_ >https.conf
map \$http_upgrade \$connection_upgrade {
	default upgrade;
	''      close;
}
server {
	listen 443 ssl http2;
	server_name ${DOMAIN};

	ssl_protocols TLSv1.2;
	ssl_ciphers EECDH+AESGCM:EECDH+AES;
	ssl_ecdh_curve prime256v1;
	ssl_prefer_server_ciphers on;
	ssl_session_cache shared:SSL:10m;
	ssl_certificate ${CERT};
	ssl_certificate_key ${PKEY};

	keepalive_timeout 70;
	sendfile on;
	client_max_body_size 0;
	root /home/mastodon/live/public;
	server_tokens off;
	charset utf-8;

	gzip on;
	gzip_disable "msie6";
	gzip_vary on;
	gzip_proxied any;
	gzip_comp_level 6;
	gzip_buffers 16 8k;
	gzip_http_version 1.1;
	gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
	add_header Strict-Transport-Security "max-age=31536000";

	location / {
		try_files \$uri @proxy;
	}

	location ~ ^/(packs|system/media_attachments/files|system/accounts/avatars) {
		add_header Cache-Control "public, max-age=31536000, immutable";
		try_files \$uri @proxy;
	}

	location @proxy {
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto https;
		proxy_set_header Proxy "";
		proxy_pass_header Server;
		proxy_pass http://127.0.0.1:3000;
		proxy_buffering off;
		proxy_redirect off;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection \$connection_upgrade;

		tcp_nodelay on;
	}

	location /api/v1/streaming {
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto https;
		proxy_set_header Proxy "";
		proxy_pass http://localhost:4000;
		proxy_buffering off;
		proxy_redirect off;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection \$connection_upgrade;

		tcp_nodelay on;
	}

	error_page 500 501 502 503 504 /500.html;
}
_EOF_
systemctl enable nginx
systemctl start nginx

#postfix
cat <<_EOL_ >>/etc/postfix/main.cf
myhostname = ${DOMAIN}
smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt
smtp_tls_security_level = may
smtp_tls_loglevel = 1
smtpd_client_connection_count_limit = 9
disable_vrfy_command = yes
smtpd_discard_ehlo_keywords = dsn, enhancedstatuscodes, etrn
_EOL_
sed -i -e 's/^inet_interfaces.*/inet_interfaces = all/' -e 's/^inet_protocols = all/inet_protocols = ipv4/' /etc/postfix/main.cf
systemctl reload postfix

FWSTAT=$(systemctl status firewalld.service | awk '/Active/ {print $2}')

if [ "${FWSTAT}" = "inactive" ]; then
    systemctl start firewalld.service
    firewall-cmd --zone=public --add-service=ssh --permanent
    systemctl enable firewalld.service
fi

firewall-cmd --permanent --add-port={25,80,443}/tcp
firewall-cmd --reload

#Lets Encrypt
CPATH=/usr/local/certbot
git clone https://github.com/certbot/certbot ${CPATH}
WROOT=/usr/share/nginx/html
${CPATH}/certbot-auto -n certonly --webroot -w ${WROOT} -d ${DOMAIN} -m ${MADDR} --agree-tos --server https://acme-v02.api.letsencrypt.org/directory

if [ ! -f ${CERT} ]; then
    echo "証明書の取得に失敗しました"
    exit 1
fi

mv https.conf /etc/nginx/conf.d/
R=${RANDOM}
echo "$((${R} % 60)) $((${R} % 24)) * * $((${R} % 7)) root ${CPATH}/certbot-auto renew --webroot -w ${WROOT} --post-hook 'systemctl reload nginx'" >/etc/cron.d/certbot-auto

# reboot
shutdown -r 1

echo "スタートアップスクリプトが正常に完了しました"

exit 0
