#!/usr/bin/env bash

###########################################################
# Postfix
###########################################################

function postfix_install_loopback_only {
	# Installs postfix and configure to listen only on the local interface. Also
	# allows for local mail delivery

	echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
	echo "postfix postfix/mailname string localhost" | debconf-set-selections
	echo "postfix postfix/destinations string localhost.localdomain, localhost" | debconf-set-selections
	aptitude -y install postfix
	/usr/sbin/postconf -e "inet_interfaces = loopback-only"
	#/usr/sbin/postconf -e "local_transport = error:local delivery is disabled"

	touch /tmp/restart-postfix
}


###########################################################
# Apache
###########################################################

function apache_install {
	# installs the system default apache2 MPM
	aptitude -y install apache2

	a2dissite default # disable the interfering default virtualhost

	# clean up, or add the NameVirtualHost line to ports.conf
	sed -i -e 's/^NameVirtualHost \*$/NameVirtualHost *:80/' /etc/apache2/ports.conf
	if ! grep -q NameVirtualHost /etc/apache2/ports.conf; then
		echo 'NameVirtualHost *:80' > /etc/apache2/ports.conf.tmp
		cat /etc/apache2/ports.conf >> /etc/apache2/ports.conf.tmp
		mv -f /etc/apache2/ports.conf.tmp /etc/apache2/ports.conf
	fi
}

function apache_tune {
	# Tunes Apache's memory to use the percentage of RAM you specify, defaulting to 40%

	# $1 - the percent of system memory to allocate towards Apache

	if [ ! -n "$1" ];
		then PERCENT=40
		else PERCENT="$1"
	fi

	aptitude -y install apache2-mpm-prefork
	PERPROCMEM=10 # the amount of memory in MB each apache process is likely to utilize
	MEM=$(grep MemTotal /proc/meminfo | awk '{ print int($2/1024) }') # how much memory in MB this system has
	MAXCLIENTS=$((MEM*PERCENT/100/PERPROCMEM)) # calculate MaxClients
	MAXCLIENTS=${MAXCLIENTS/.*} # cast to an integer
	sed -i -e "s/\(^[ \t]*MaxClients[ \t]*\)[0-9]*/\1$MAXCLIENTS/" /etc/apache2/apache2.conf

	touch /tmp/restart-apache2
}

function apache_virtualhost {
	# Configures a VirtualHost

	# $1 - required - the hostname of the virtualhost to create 

	if [ ! -n "$1" ]; then
		echo "apache_virtualhost() requires the hostname as the first argument"
		return 1;
	fi

	if [ -e "/etc/apache2/sites-available/$1" ]; then
		echo /etc/apache2/sites-available/$1 already exists
		return;
	fi

	mkdir -p /srv/www/$1/public_html /srv/www/$1/logs

	echo "<VirtualHost *:80>" > /etc/apache2/sites-available/$1
	echo "    ServerName $1" >> /etc/apache2/sites-available/$1
	echo "    DocumentRoot /srv/www/$1/public_html/" >> /etc/apache2/sites-available/$1
	echo "    ErrorLog /srv/www/$1/logs/error.log" >> /etc/apache2/sites-available/$1
    echo "    CustomLog /srv/www/$1/logs/access.log combined" >> /etc/apache2/sites-available/$1
	echo "</VirtualHost>" >> /etc/apache2/sites-available/$1

	a2ensite $1

	touch /tmp/restart-apache2
}

function apache_virtualhost_from_rdns {
	# Configures a VirtualHost using the rdns of the first IP as the ServerName

	apache_virtualhost $(get_rdns_primary_ip)
}


function apache_virtualhost_get_docroot {
	if [ ! -n "$1" ]; then
		echo "apache_virtualhost_get_docroot() requires the hostname as the first argument"
		return 1;
	fi

	if [ -e /etc/apache2/sites-available/$1 ];
		then echo $(awk '/DocumentRoot/ {print $2}' /etc/apache2/sites-available/$1 )
	fi
}

###########################################################
# PHP functions
###########################################################

function php_install_with_apache {
	aptitude -y install php5 php5-mysql libapache2-mod-php5
	touch /tmp/restart-apache2
}

function php_tune {
	# Tunes PHP to utilize up to 32M per process

	sed -i'-orig' 's/memory_limit = [0-9]\+M/memory_limit = 32M/' /etc/php5/apache2/php.ini
	touch /tmp/restart-apache2
}

###########################################################
# Wordpress functions
###########################################################

function wordpress_install {
	# installs the latest wordpress tarball from wordpress.org

	# $1 - required - The existing virtualhost to install into

	if [ ! -n "$1" ]; then
		echo "wordpress_install() requires the vitualhost as its first argument"
		return 1;
	fi

	if [ ! -e /usr/bin/wget ]; then
		aptitude -y install wget
	fi

	VPATH=$(apache_virtualhost_get_docroot $1)

	if [ ! -n "$VPATH" ]; then
		echo "Could not determine DocumentRoot for $1"
		return 1;
	fi

	# download, extract, chown, and get our config file started
	cd $VPATH
	wget http://wordpress.org/latest.tar.gz
	tar xfz latest.tar.gz
	chown -R www-data: wordpress/
	cd $VPATH/wordpress
	cp wp-config-sample.php wp-config.php
	chown www-data wp-config.php
	chmod 640 wp-config.php

	# database configuration
	WPPASS=$(randomString 20)
	mysql_create_database "$DB_PASSWORD" wordpress
	mysql_create_user "$DB_PASSWORD" wordpress "$WPPASS"
	mysql_grant_user "$DB_PASSWORD" wordpress wordpress

	# configuration file updates
	for i in {1..4}
		do sed -i "0,/put your unique phrase here/s/put your unique phrase here/$(randomString 50)/" wp-config.php
	done

	sed -i 's/database_name_here/wordpress/' wp-config.php
	sed -i 's/username_here/wordpress/' wp-config.php
	sed -i "s/password_here/$WPPASS/" wp-config.php

	# http://downloads.wordpress.org/plugin/wp-super-cache.0.9.8.zip
}

###########################################################
# Other niceties!
###########################################################

function goodstuff {
	# Installs the REAL vim, wget, less, and enables color root prompt and the 'll' list long alias

	aptitude -y install wget vim less
	sed -i -e 's/^#PS1=/PS1=/' /root/.bashrc # enable the colorful root bash prompt
	sed -i -e "s/^#alias ll='ls -l'/alias ll='ls -al'/" /root/.bashrc # enable ll list long alias <3
}


###########################################################
# utility functions
###########################################################

function restartServices {
	# restarts services that have a file in /tmp/needs-restart/

	for service in $(ls /tmp/restart-* | cut -d- -f2); do
		/etc/init.d/$service restart
		rm -f /tmp/restart-$service
	done
}

function randomString {
	if [ ! -n "$1" ];
		then LEN=20
		else LEN="$1"
	fi

	echo $(</dev/urandom tr -dc A-Za-z0-9 | head -c $LEN) # generate a random string
}
