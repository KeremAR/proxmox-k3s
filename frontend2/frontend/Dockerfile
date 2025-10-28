# Stage 1: Build the application
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies)
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

FROM caddy:2.10.2-alpine

# Copy built static files
COPY --from=builder /app/dist /usr/share/caddy

# Copy Caddy configuration
COPY Caddyfile /etc/caddy/Caddyfile

# Run as non-root user for security
USER caddy

EXPOSE 3000

# Caddy runs automatically, no need for CMD