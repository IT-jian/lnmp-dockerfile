#!/bin/sh
set -e 
cp -f $CODE_PATH/$PHP_ENV_FILE $CODE_PATH/.env
chmod -R 777 $CODE_PATH/storage

#/usr/sbin/crond   -f  -L  /var/log/cron/cron.log
supervisord --nodaemon --configuration /etc/supervisor/conf.d/supervisord.conf

