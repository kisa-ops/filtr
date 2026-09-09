# syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# Stage 1: Build stage
# -----------------------------------------------------------------------------
FROM node:22-alpine AS builder

WORKDIR /app

# Install dependencies first (leverages Docker layer cache)
COPY package.json package-lock.json ./
RUN npm ci

# Copy application source
COPY . .

# Build production bundle
RUN npm run build

# -----------------------------------------------------------------------------
# Stage 2: Production Nginx stage
# -----------------------------------------------------------------------------
FROM nginx:alpine AS production

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy built static assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:80/healthz || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
