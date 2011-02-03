#!/bin/bash

read -p "Remote username:" REMOTE_USERNAME
read -p "Remote host:" REMOTE_HOST

cat ~/.ssh/id_rsa.pub | ssh $REMOTE_USERNAME@$REMOTE_HOST "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && cat - >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"
