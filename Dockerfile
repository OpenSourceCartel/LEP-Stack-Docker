FROM jkirkby91/ubuntusrvbase
MAINTAINER James Kirkby <jkirkby91@gmail.com>

# add a non root account
RUN adduser --disabled-password --gecos "" woodhouse

# Add ssh deployment keys
ADD ./confs/id_rsa /woodhouse/.ssh/
ADD ./confs/id_rsa.pub /woodhouse/.ssh/id_rsa.pub/

# Update base image
# Add sources for latest nginx
# Install software requirements
RUN add-apt-repository ppa:nginx/$nginx && \
apt-get update && \
apt-get upgrade -y && \
apt-get install -y sqlite3 libsqlite3-dev supervisor nginx php5-fpm php5-mysql php5-curl php5-gd php5-intl php5-mcrypt php5-tidy php5-xmlrpc php5-xsl php5-xdebug php-pear && \
apt-get remove --purge -y software-properties-common && \
apt-get autoremove -y && \
apt-get clean && \
apt-get autoclean && \
echo -n > /var/lib/apt/extended_states && \
rm -rf /var/lib/apt/lists/* && \
rm -rf /usr/share/man/?? && \
rm -rf /usr/share/man/??_*

# Link nodejs env
RUN ln -s /usr/bin/nodejs /usr/bin/node

# install bower
RUN npm install -g bower

# install gulp
RUN npm install -g gulp

# install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# tweak nginx config
RUN sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf && \
sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf && \
echo "daemon off;" >> /etc/nginx/nginx.conf

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php5/fpm/pool.d/www.conf

# fix ownership of sock file for php-fpm
RUN sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php5/fpm/pool.d/www.conf && \
find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# set owners of web folders before mounting
RUN usermod -u 1000 www-data

# set some environment vars
ENV APP_NAME=my_new_app
ENV LOCAL_IP=192.168.34.117
ENV APP_VOL_DIR=sites
ENV WEB_ROOT_FOLDER=public
ENV PATH=$APP_NAME/sbin:$APP_VOL_DIR/common/bin:$PATH
ENV TERM xterm
ENV GIT_EMAIL=deploy@gmail.com
ENV GIT_NAME=Dev_team
ENV GIT_REPO=git@bitbucket.org:user/repo.git
ENV GIT_BRANCH=production
ENV BUILD_FILE=build.sh
ENV DEBIAN_FRONTEND noninteractive

# Configure Xdebug
RUN echo "zend_extension=/usr/lib/php5/20121212/xdebug.so" >> /etc/php5/fpm/php.ini
RUN echo "xdebug.remote_enable = 0" >> /etc/php5/fpm/php.ini
RUN echo "xdebug.idekey = 'dev_docker'" >> /etc/php5/fpm/php.ini
RUN echo "xdebug.remote_autostart = 1" >> /etc/php5/fpm/php.ini
RUN echo "xdebug.remote_connect_back = $LOCAL_IP" >> /etc/php5/fpm/php.ini
RUN echo "xdebug.remote_port = 9000" >> /etc/php5/fpm/php.ini
RUN echo "xdebug.remote_handler=dbgp" >> /etc/php5/fpm/php.ini

# Create Mounted Folders
RUN mkdir /$APP_VOL_DIR/ && \
mkdir /$APP_VOL_DIR/www

# set folder groups
RUN chown -Rf www-data:www-data /$APP_VOL_DIR

# Mount folders
VOLUME ["/$APP_VOL_DIR/www"]

# Expose Ports
EXPOSE 443

# Add git commands to allow container updating
ADD ./pull /usr/bin/pull
ADD ./push /usr/bin/push
RUN chmod 755 /usr/bin/pull && chmod 755 /usr/bin/push

# Supervisor Config
ADD ./confs/supervisord.conf /etc/supervisord.conf

# Add entry point script
ADD ./start.sh /start.sh

# nginx site conf
RUN sudo mkdir /etc/nginx/ssl
RUN rm -Rf /etc/nginx/sites-enabled/*
ADD ./confs/nginx.conf /etc/nginx/sites-enabled/default.conf
ADD ./confs/nginx.key /etc/nginx/ssl/nginx.key
ADD ./confs/nginx.crt /etc/nginx/ssl/nginx.crt
RUN chmod 400 /etc/nginx/ssl/*

# copy composer github auth token
ADD ./confs/auth.json /root/.composer/

CMD ["/bin/bash", "/start.sh"]
