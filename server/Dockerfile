# Cloud Run container
FROM node:20-slim

WORKDIR /app

# Install deps
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev

# Copy source and build
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080
CMD ["npm", "start"]
