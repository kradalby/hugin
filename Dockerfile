FROM node:10 as builder
WORKDIR /app

ARG MAPBOX_ACCESS_TOKEN

COPY package.json .
COPY yarn.lock .
RUN yarn install --silent
COPY elm.json .

ENV NODE_ENV "production"
COPY . .
RUN yarn run prod


FROM kradalby/nginx-ldap-auth:1.15.3 as production
COPY --from=builder /app/dist /usr/share/nginx/html
