#!/bin/bash

# Disable Strict Host checking for non interactive git clones

mkdir -p -m 0700 /root/.ssh
echo -e "Host *\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

# Setup git variables
if [ ! -z "$GIT_EMAIL" ]; then
 git config --global user.email "$GIT_EMAIL"
fi
if [ ! -z "$GIT_NAME" ]; then
 git config --global user.name "$GIT_NAME"
 git config --global push.default simple
fi

# Pull down code form git for our site!
if [ ! -z "$GIT_REPO" ]; then
  rm /sites/www/*
  if [ ! -z "$GIT_BRANCH" ]; then
    git clone -b $GIT_BRANCH $GIT_REPO /sites/www/
  else
    git clone $GIT_REPO /sites/www/
  fi
  chown -Rf www-data:www-data /sites/www/*
fi

# Tweak nginx to match the workers to cpu's

procs=$(cat /proc/cpuinfo |grep processor | wc -l)
sed -i -e "s/worker_processes 5/worker_processes $procs/" /etc/nginx/nginx.conf

# Very dirty hack to replace variables in code with ENVIRONMENT values
#if [[ "$TEMPLATE_NGINX_HTML" != "0" ]] ; then
#  for i in $(env)
#  do
#    variable=$(echo "$i" | cut -d'=' -f1)
#    value=$(echo "$i" | cut -d'=' -f2)
#    if [[ "$variable" != '%s' ]] ; then
#      replace='\$\$_'${variable}'_\$\$'
#      find /usr/share/nginx/html -type f -exec sed -i -e 's/'${replace}'/'${value}'/g' {} \;
#    fi
#  done
#fi

# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisord.conf
