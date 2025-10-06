# Simple Node.js serve approach
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Install serve globally
RUN npm install -g serve

EXPOSE 3000

# Serve the built files
CMD ["serve", "-s", "dist", "-l", "3000"]
