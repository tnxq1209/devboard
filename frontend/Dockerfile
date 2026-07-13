#stage:1(Builder stage)
FROM node:24 as builder

WORKDIR /app

COPY . .

RUN npm install

RUN npm run build #(creates a foleder /dist)

#stage:2(Runner stage)
FROM node:24-alpine

WORKDIR /app

COPY --from=builder /app/dist ./dist


COPY package*.json ./
COPY vite.config.js .

RUN npm install

EXPOSE 4173
CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0", "--port", "4173"]
