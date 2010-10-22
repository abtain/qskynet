#!/usr/bin/env bash

# 
source mysql.sh

# Set up MySQL
  mysql_install "$DB_PASSWORD" && mysql_tune 40
  #log "MySQL installed"

