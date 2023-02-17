FROM alpine

LABEL Petro Skaletskyy
LABEL Final Task

WORKDIR /usr/src/app 

RUN apk add --update nodejs npm

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
COPY src/. ./
COPY build/default.conf /etc/nginx/http.d/default.conf

#Make sure the nginx starts when system reboots
RUN rc-update add nginx default

#Create script for starting nginx in container
COPY ./script.sh ./
RUN chmod +x ./script.sh

EXPOSE 3000

ENTRYPOINT ["./script.sh"]