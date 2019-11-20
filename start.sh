#!/bin/sh

echo " Clapp_project Ex-potato"

echo "Kantan-Installer Ver 1.0"

echo "インストールするものを選んでください"
export LANG=ja_JP.utf8

#1) Install Mastodon 3.0
#2) Install  Gitlab
#3) Install  Mattermost
#4) Exit and Cancel

select VAR in Install Mastodon 3.0 Install  Gitlab Install  Mattermost Exit and Cancel

do
      echo "You Choose $VAR !"
         if [ "$VAR" = "Install Mastodon 3.0" ]; then
           sh Mastodon.sh
         fi
         if [ "$VAR" = "Install  Gitlab" ]; then
           sh Gitlab.sh
         fi
         if [ "$VAR" = "Install  Mattermost" ]; then
           sh Mattermost.sh
         fi
        if [ "$VAR" = "Exit and Cancel" ]; then
            break
          fi
done
