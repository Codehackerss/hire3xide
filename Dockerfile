# Stage 1: Build Stage
FROM node:18.20.4-alpine AS build

# Set the working directory
WORKDIR /workspace

# Install necessary build tools and dependencies
RUN apk add --no-cache --virtual .build-deps \
    git \
    python3 \
    make \
    gcc \
    g++ \
    pkgconfig \
    libx11-dev \
    libxkbfile-dev \
    libsecret-dev \
    openjdk17-jdk \
    go \
    py3-setuptools && \
    git clone https://github.com/Codehackerss/hire3xide.git theia && \
    cd theia && \
    yarn install && \
    yarn add -W react react-dom && \
    yarn download:plugins && \
    yarn browser build && \
    apk del .build-deps

# Stage 2: Runtime Stage
FROM node:18.20.4-alpine

# Install only the necessary runtime dependencies
RUN apk add --no-cache \
    python3 \
    openjdk17-jdk \
    go \
    git \
    openssh \
    bash

# Create a non-root user and group named "theia"
RUN addgroup -S theia && \
    adduser -S theia -G theia -s /bin/sh

# Set the home directory and working directory for the "theia" user
ENV HOME=/home/theia
WORKDIR /home/theia

# Create a "project" directory where the user will have full access
RUN mkdir -p $HOME/project && \
    chown -R theia:theia $HOME/project

# Copy only the necessary files from the build stage
COPY --from=build /workspace/theia /home/theia/theia

# Change ownership of the Theia directory to the "theia" user
RUN chown -R theia:theia /home/theia/theia

# Set the user to "theia"
USER theia

# Set the correct working directory for the Theia application
WORKDIR /home/theia/theia

# Expose port 3000 for the Theia application
EXPOSE 3000

# Start the Theia browser application
CMD ["yarn", "browser", "start", "--hostname", "0.0.0.0","#/home/theia/project"]
