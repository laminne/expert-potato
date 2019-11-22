#!bin/bash

echo "---------------------------"
echo "Gitlab Installer"
echo "---------------------------"
set -x
echo "starting install..."

curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
echo "Start install..."
sudo yum install -y gitlab-ce
