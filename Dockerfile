# Use the official Node.js image
FROM node:14-alpine AS build

# Create and change to the app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm install --production

# Copy app files
COPY . .

# Stage 2: Create the runtime image
FROM node:14-alpine

# Create and change to the app directory
WORKDIR /usr/src/app

# Copy only the necessary files from the build stage
COPY --from=build /usr/src/app .

#Expose the application port
EXPOSE 3000

# Start the app
CMD ["npm", "start"]

