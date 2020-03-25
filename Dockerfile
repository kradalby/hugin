FROM node:10 as builder
WORKDIR /app

ARG HUGIN_MAPBOX_ACCESS_TOKEN
ARG HUGIN_SENTRY_DSN
ARG HUGIN_ROLLBAR_ACCESS_TOKEN

COPY package.json .
COPY yarn.lock .
RUN yarn
COPY elm.json .

COPY . .
RUN make build


FROM kradalby/nginx-ldap-auth:latest as production
COPY --from=builder /app/dist /usr/share/nginx/html
