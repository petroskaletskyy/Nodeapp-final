#!/bin/sh
nginx -t
openrc
touch /run/openrc/softlevel
rc-service nginx start
npm start