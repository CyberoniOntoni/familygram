# FamilyGram Web — multi-stage build (telegram-tt fork)
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

ARG TELEGRAM_API_ID
ARG TELEGRAM_API_HASH
ARG PRODUCTION_HOSTNAME
ARG BASE_URL
ARG APP_NAME="FamilyGram Web"
ARG APP_TITLE="FamilyGram"

ENV FAMILYGRAM_SELF_HOSTED=1 \
    TELEGRAM_API_ID=${TELEGRAM_API_ID} \
    TELEGRAM_API_HASH=${TELEGRAM_API_HASH} \
    PRODUCTION_HOSTNAME=${PRODUCTION_HOSTNAME} \
    BASE_URL=${BASE_URL} \
    APP_NAME=${APP_NAME} \
    APP_TITLE=${APP_TITLE} \
    APP_ENV=production

RUN npm run build:production

FROM nginx:1.27-alpine

COPY --from=build /app/dist /usr/share/nginx/html
COPY docker/default.conf.template /etc/nginx/templates/default.conf.template

ENV GATEWAY_UPSTREAM=gateway-server:30444 \
    LISTEN_PORT=8082

EXPOSE 8082