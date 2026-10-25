# Stage 1: Build the React application
FROM node:24-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# Stage 2: Serve the static application
FROM nginx:alpine

RUN apk update && apk upgrade --no-cache

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

ENV BACKEND_URL=http://backend:8080
ENV NGINX_ENVSUBST_FILTER=^BACKEND_URL$

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
