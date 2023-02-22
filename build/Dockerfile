FROM node:alpine3.16

LABEL Petro Skaletskyy
LABEL Final Task

WORKDIR /usr/src/app

#Copy package.json for installing dependencies 
COPY src/package*.json ./

#Install NodeJS dependencies
RUN npm install

#Copy NodeJS project
COPY src/. ./

RUN apk update \
    && apk add nginx --no-cache \
    && rm -rf /var/cache/apk/*

COPY build/default.conf /etc/nginx/http.d/default.conf

EXPOSE 3000

CMD npm run && nginx start