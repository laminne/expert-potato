#!/bin/sh

echo " Clapp_project Ex-potato"

echo "Kantan-Installer Ver 1.0"

echo "インストールするものを選んでください"
export LANG=ja_JP.utf8

#1) Mastodon 3.0
#2) Gitlab
#3) Mattermost
#4) Exit and Cancel

select VAR in Mastodon3.0 Gitlab Mattermost Exit

do
      echo "$VAR !"
         if [ "$VAR" = "Mastodon3.0" ]; then
           sh Mastodon.sh
         fi
         if [ "$VAR" = "Gitlab" ]; then
           sh Gitlab.sh
         fi
         if [ "$VAR" = "Mattermost" ]; then
           sh Mattermost.sh
         fi
        if [ "$VAR" = "Exit" ]; then
            break
          fi
done
