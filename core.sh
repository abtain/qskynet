#!/bin/bash

##########
# System #
##########

# Updates Packages
function system_update {
  aptitude update
  aptitude -y full-upgrade
}

function install_package {
  aptitude -y install $*
}

######################
# System Information #
######################

# returns the primary IP assigned to eth0
function system_primary_ip {
  echo $(ifconfig eth0 | awk -F: '/inet addr:/ {print $2}' | awk '{ print $1 }')
}

# calls host on an IP address and returns its reverse dns
function reverse_dns {
  if [ ! -e /usr/bin/host ]; then
    aptitude -y install dnsutils > /dev/null
  fi
  echo $(host $1 | awk '/pointer/ {print $5}' | sed 's/\.$//')
}

# returns the reverse dns of the primary IP assigned to this system
function reverse_primary_ip {
  echo $(reverse_dns $(system_primary_ip))
}

function system_memory {
  echo $(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo) 
}

###########
# Postfix #
###########

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

################
# MySQL Server #
################

function mysql_install {
	# $1 - the mysql root password

	if [ ! -n "$1" ]; then
		echo "mysql_install() requires the root pass as its first argument"
		return 1;
	fi

	echo "mysql-server-5.1 mysql-server/root_password password $1" | debconf-set-selections
	echo "mysql-server-5.1 mysql-server/root_password_again password $1" | debconf-set-selections
	apt-get -y install mysql-server mysql-client

	echo "Sleeping while MySQL starts up for the first time..."
	sleep 5
}

function mysql_tune {
	# Tunes MySQL's memory usage to utilize the percentage of memory you specify, defaulting to 40%

	# $1 - the percent of system memory to allocate towards MySQL

	if [ ! -n "$1" ];
		then PERCENT=40
		else PERCENT="$1"
	fi

	sed -i -e 's/^#skip-innodb/skip-innodb/' /etc/mysql/my.cnf # disable innodb - saves about 100M

	MEM=$(system_memory) # how much memory in MB this system has
	MYMEM=$((MEM*PERCENT/100)) # how much memory we'd like to tune mysql with
	MYMEMCHUNKS=$((MYMEM/4)) # how many 4MB chunks we have to play with

	# mysql config options we want to set to the percentages in the second list, respectively
	OPTLIST=(key_buffer sort_buffer_size read_buffer_size read_rnd_buffer_size myisam_sort_buffer_size query_cache_size)
	DISTLIST=(75 1 1 1 5 15)

	for opt in ${OPTLIST[@]}; do
		sed -i -e "/\[mysqld\]/,/\[.*\]/s/^$opt/#$opt/" /etc/mysql/my.cnf
	done

	for i in ${!OPTLIST[*]}; do
		val=$(echo | awk "{print int((${DISTLIST[$i]} * $MYMEMCHUNKS/100))*4}")
		if [ $val -lt 4 ]
			then val=4
		fi
		config="${config}\n${OPTLIST[$i]} = ${val}M"
	done

	sed -i -e "s/\(\[mysqld\]\)/\1\n$config\n/" /etc/mysql/my.cnf

	touch /tmp/restart-mysql
}

function mysql_create_database {
	# $1 - the mysql root password
	# $2 - the db name to create

	if [ ! -n "$1" ]; then
		echo "mysql_create_database() requires the root pass as its first argument"
		return 1;
	fi
	if [ ! -n "$2" ]; then
		echo "mysql_create_database() requires the name of the database as the second argument"
		return 1;
	fi

	echo "CREATE DATABASE $2;" | mysql -u root -p$1
}

function mysql_create_user {
	# $1 - the mysql root password
	# $2 - the user to create
	# $3 - their password

	if [ ! -n "$1" ]; then
		echo "mysql_create_user() requires the root pass as its first argument"
		return 1;
	fi
	if [ ! -n "$2" ]; then
		echo "mysql_create_user() requires username as the second argument"
		return 1;
	fi
	if [ ! -n "$3" ]; then
		echo "mysql_create_user() requires a password as the third argument"
		return 1;
	fi

	echo "CREATE USER '$2'@'localhost' IDENTIFIED BY '$3';" | mysql -u root -p$1
}

function mysql_grant_user {
	# $1 - the mysql root password
	# $2 - the user to bestow privileges 
	# $3 - the database

	if [ ! -n "$1" ]; then
		echo "mysql_create_user() requires the root pass as its first argument"
		return 1;
	fi
	if [ ! -n "$2" ]; then
		echo "mysql_create_user() requires username as the second argument"
		return 1;
	fi
	if [ ! -n "$3" ]; then
		echo "mysql_create_user() requires a database as the third argument"
		return 1;
	fi

	echo "GRANT ALL PRIVILEGES ON $3.* TO '$2'@'localhost';" | mysql -u root -p$1
	echo "FLUSH PRIVILEGES;" | mysql -u root -p$1

}

#######
# RVM #
#######

function install_rvm_dependencies {
  install_package curl bison build-essential zlib1g-dev libssl-dev libreadline5-dev libxml2-dev git-core
}

function install_rvm {
  export rvm_group_name="rvm"
  install_rvm_dependencies
  bash < <( curl -L http://bit.ly/rvm-install-system-wide )
}

########
# SUDO #
########

function create_sudo_group {
  groupadd wheel
  # add group to sudoers
  cp /etc/sudoers /etc/sudoers.tmp
  chmod 0640 /etc/sudoers.tmp
  echo "%wheel ALL = (ALL) ALL" >> /etc/sudoers.tmp
  chmod 0440 /etc/sudoers.tmp
  mv /etc/sudoers.tmp /etc/sudoers
}

function create_sudo_user {
  useradd -m -s /bin/bash -G wheel "$ADMIN_LOGIN"
  echo "${ADMIN_LOGIN}:${ADMIN_PASSWORD}" | chpasswd
  usermod -a -G "$GROUP_NAME" "$ADMIN_LOGIN"
}  

function install_sudo {
  install_package sudo
  create_sudo_group
}

#############
# Passenger #
#############

function install_passenger {
  # Set up Nginx and Passenger
  log "Installing Nginx and Passenger"
  gem install passenger
  passenger-install-nginx-module --auto --auto-download --prefix="/usr/local/nginx"
  log "Passenger and Nginx installed"

  # Configure nginx to start automatically
  wget http://library.linode.com/web-servers/nginx/installation/reference/init-deb.sh
  cat init-deb.sh | sed 's:/opt/:/usr/local/:' > /etc/init.d/nginx
  chmod +x /etc/init.d/nginx
  /usr/sbin/update-rc.d -f nginx defaults
  log "Nginx configured to start automatically"
}

###################
# Other niceties! #
###################

# Installs the REAL vim, wget, less, and enables color root prompt and the "ll" list long alias
function goodstuff {
  aptitude -y install wget vim less
  sed -i -e 's/^#PS1=/PS1=/' /root/.bashrc # enable the colorful root bash prompt
  sed -i -e "s/^#alias ll='ls -l'/alias ll='ls -al'/" /root/.bashrc # enable ll list long alias <3
}

# Sets the hostname to the reverse dns
function set_hostname {
  hostname `reverse_primary_ip`
}

#### the meat, to be extracted ####

ADMIN_LOGIN=deploy
#read -p "Admin account password:" ADMIN_PASSWORD
ADMIN_PASSWORD=$1

system_update
set_hostname
goodstuff
install_sudo
create_sudo_user
install_rvm
install_passenger
