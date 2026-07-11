#stage:1(Builder stage)
FROM node:24 as builder

WORKDIR /app

COPY . .

RUN npm install

EXPOSE 4173

CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0", "--port", "4173"]
