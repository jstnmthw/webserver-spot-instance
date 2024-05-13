#!/bin/bash

git clone https://github.com/jstnmthw/srcds-autoinstall.git ~/srcds-autoinstall

cd ~/srcds-autoinstall
touch .env

make install SCRIPT=server-example.sh GAME=tfc CONFIG=classic CONTAINER=tfc1