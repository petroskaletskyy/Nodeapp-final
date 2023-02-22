FROM ngnix:alpine

LABEL Petro Skaletskyy
LABEL Final Task

WORKDIR /usr/src/app 

RUN apk add --update nodejs npm

#Copy package.json for installing dependencies 
COPY src/package*.json ./

#Install NodeJS dependencies
RUN npm install

#Copy NodeJS project
COPY src/. ./

COPY build/default.conf /etc/nginx/http.d/default.conf

EXPOSE 3000

ENTRYPOINT ["npm start"]