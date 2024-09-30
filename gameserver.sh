#!/bin/bash

git clone https://github.com/jstnmthw/srcds-autoinstall.git ~/srcds-autoinstall

cd ~/srcds-autoinstall
touch .env

make install SCRIPT=cs2-example