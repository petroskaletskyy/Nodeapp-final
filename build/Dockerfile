FROM node:alpine

LABEL Petro Skaletskyy
LABEL Final Task

WORKDIR /usr/src/app 

#Copy package.json for installing dependencies 
COPY src/package*.json ./

#Install NodeJS dependencies
RUN npm install

#Install nginx
RUN apk update \
    && apk add nginx --no-cache \
    && apk add openrc --no-cache \
    && rm -rf /var/cache/apk/*

#Copy NodeJS project
COPY src/. .

#Make sure the nginx starts when system reboots
RUN rc-update add nginx default

COPY build/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000

ENTRYPOINT ["npm", "start"]