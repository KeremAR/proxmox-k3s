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

# Stage 2: Serve the application
FROM node:20-alpine

WORKDIR /app

# Install serve globally
RUN npm install -g serve

# Copy the built application from the builder stage
COPY --from=builder /app/dist ./dist

EXPOSE 3000

# Serve the built files
CMD ["serve", "-s", "dist", "-l", "3000"]