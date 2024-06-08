# Use the official Node.js image
FROM node:14-alpine

# Create and change to the app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm install --production

# Copy app files
COPY . .

# Start the app
CMD ["npm", "start"]

