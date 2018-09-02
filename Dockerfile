FROM node:10 as builder
WORKDIR /app

RUN yarn global add elm@0.18.0

ADD package.json .
RUN npm install --silent
ADD elm-package.json .
RUN elm package install -y

ENV NODE_ENV "production"
ADD . .
RUN npm run prod


FROM kradalby/nginx-ldap-auth:1.15.3 as production 
COPY --from=builder /app/dist /usr/share/nginx/html
