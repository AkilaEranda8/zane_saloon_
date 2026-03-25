# Build stage
FROM node:18-alpine AS build

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

COPY . .

# Accept AI bot URL at build time (injected by docker-compose)
ARG VITE_AI_BOT_URL=/aibot
ENV VITE_AI_BOT_URL=$VITE_AI_BOT_URL

RUN npm run build

# Production stage
FROM nginx:alpine

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
