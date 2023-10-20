FROM node:21-alpine3.17
WORKDIR /app
COPY . .
RUN npm install && \
    cd frontend && \
    npm install
WORKDIR /app/frontend
CMD ["npm","run","dev"]
