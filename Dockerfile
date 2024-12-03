# Stage 1: Build Stage
FROM ubuntu:22.04 AS build

# Install build tools and dependencies
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    build-essential \
    pkg-config \
    libx11-dev \
    libxkbfile-dev \
    libsecret-1-dev \
    python3-setuptools \
    python3-pip \
    curl \
    gnupg && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn && \
    git clone https://github.com/Codehackerss/hire3xide.git theia && \
    cd theia && \
    yarn && \
    yarn download:plugins && \
    yarn browser build && \
    apt-get remove --purge -y build-essential pkg-config libx11-dev libxkbfile-dev libsecret-1-dev && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /root/.cache

# Stage 2: Runtime Stage
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    git \
    bash \
    curl \
    gnupg && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Install ngrok
RUN curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
    gpg --dearmor -o /etc/apt/keyrings/ngrok.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com buster main" | \
    tee /etc/apt/sources.list.d/ngrok.list && \
    apt-get update && apt-get install ngrok && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Create a non-root user and group
RUN groupadd -r theia && useradd -r -g theia -s /bin/sh -m -d /home/theia theia

# Ensure ownership and permissions
RUN mkdir -p /home/theia && \
    chown -R theia:theia /home/theia && \
    chmod -R 755 /home/theia

# Restrict Git access for non-root users
RUN echo "root:KSGPdd3q0S#jl@B" | chpasswd

RUN chmod o-x /usr/bin/git && \
    chown root:root /usr/bin/git

# # Configure Bash as the default shell in Theia terminal
RUN mkdir -p /home/theia/.theia && \
    echo '{"terminal.integrated.shell.linux": "/bin/bash"}' > /home/theia/.theia/settings.json && \
    chown -R theia:theia /home/theia/.theia


# Set up Theia application
COPY --from=build /theia /home/theia/theia
WORKDIR /home/theia/theia

COPY bin/* /tmp/bin/

RUN chmod +x /tmp/bin/*

RUN mv /tmp/bin/* /usr/local/bin

COPY profile/* /tmp/.bashrc

RUN cat /tmp/.bashrc >> /home/theia/.bashrc

COPY certs/* ./

RUN chmod 644 /home/theia/theia/server.crt /home/theia/theia/server.key


# Configure certificates and Bash shell
# COPY certs/* ./
RUN chmod 644 /home/theia/theia/server.crt /home/theia/theia/server.key

# Switch to non-root user
USER theia
# RUN npm install @angular/cli --legacy-peer-deps

# Add ngrok authtoken
RUN ngrok config add-authtoken 2p4Ev9jT67lp0Ca8n0dvVPXzFnS_4G6AmzWCRa4qNSJbX9dTC

# Expose port 3000
EXPOSE 3000

# Start the application
CMD ["yarn", "browser", "start", "--hostname", "0.0.0.0", "--ssl", "--cert", "/home/theia/theia/server.crt", "--certkey", "/home/theia/theia/server.key"]

# # //For https: 
# # Stage 1: Build Stage Only python
# FROM ubuntu:22.04 AS build 

# # Install necessary build tools and dependencies
# RUN apt-get update && apt-get install -y \
#     git \
#     python3 \
#     build-essential \
#     pkg-config \
#     libx11-dev \
#     libxkbfile-dev \
#     libsecret-1-dev \
#     python3-setuptools \
#     python3-pip \
#     curl \
#     gnupg && \
#     ln -s /usr/bin/python3 /usr/bin/python && \
#     curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
#     apt-get install -y nodejs && \
#     curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg && \
#     echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
#     apt-get update && \
#     apt-get install -y yarn && \
#     node -v && \
#     python --version && pip --version && \
#     yarn -v && \
#     git clone https://github.com/Codehackerss/hire3xide.git theia && \
#     cd theia && \
#     yarn && \
#     yarn download:plugins && \
#     yarn browser build && \
#     apt-get remove --purge -y build-essential && \
#     apt-get autoremove -y && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# # Stage 2: Runtime Stage
# FROM ubuntu:22.04

# # Install necessary runtime dependencies including Node.js and Yarn
# RUN apt-get update && apt-get install -y \
#     python3 \
#     git \
#     openssh-client \
#     bash \
#     curl \
#     gnupg && \
#     curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
#     apt-get install -y nodejs && \
#     curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg && \
#     echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
#     apt-get update && \
#     apt-get install -y yarn && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# RUN curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
#     gpg --dearmor -o /etc/apt/keyrings/ngrok.gpg && \
#     echo "deb [signed-by=/etc/apt/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com buster main" | \
#     tee /etc/apt/sources.list.d/ngrok.list && \
#     apt-get update && apt-get install ngrok

# # Create a non-root user and group named "theia"
# RUN groupadd -r theia && useradd -r -g theia -s /bin/sh -m -d /home/theia theia

# # Ensure ownership and permissions for the theia user
# RUN mkdir -p /home/theia && \
#     chown -R theia:theia /home/theia && \
#     chmod -R 755 /home/theia

# # Remove Git binary access for the "theia" user
# RUN mv /usr/bin/git /usr/bin/git-root-only && \
#     echo 'alias git="echo Git access is restricted for non-root users."' >> /home/theia/.bashrc && \
#     chown theia:theia /home/theia/.bashrc

# # Configure Bash as the default shell in Theia terminal
# RUN mkdir -p /home/theia/.theia && \
#     echo '{"terminal.integrated.shell.linux": "/bin/bash"}' > /home/theia/.theia/settings.json && \
#     chown -R theia:theia /home/theia/.theia

# # Copy only the necessary files from the build stage
# COPY --from=build /theia /home/theia/theia

# # Set the correct working directory for the Theia application
# WORKDIR /home/theia/theia

# COPY bin/* /tmp/bin/

# RUN chmod +x /tmp/bin/*

# RUN mv /tmp/bin/* /usr/local/bin

# COPY profile/* /tmp/.bashrc

# RUN cat /tmp/.bashrc >> /home/theia/.bashrc

# COPY certs/* ./

# RUN chmod 644 /home/theia/theia/server.crt /home/theia/theia/server.key

# # Switch to the "theia" user
# USER theia

# RUN ngrok config add-authtoken 2cH6VRUb0PAQ1Zz0uh034dkj0fi_6ahNU9DacwbBqhdqHN36e

# # Expose port 3000 for the Theia application
# EXPOSE 3000

# # Start the Theia browser application
# CMD ["yarn", "browser", "start", "--hostname", "0.0.0.0", "--ssl", "--cert", "/home/theia/theia/server.crt", "--certkey", "/home/theia/theia/server.key"]






# //For readme file open But not working
# # Stage 1: Build Stage Only python
# FROM ubuntu:22.04 AS build 

# # Install necessary build tools and dependencies
# RUN apt-get update && apt-get install -y \
#     git \
#     python3 \
#     build-essential \
#     pkg-config \
#     libx11-dev \
#     libxkbfile-dev \
#     libsecret-1-dev \
#     python3-setuptools \
#     python3-pip \
#     curl \
#     gnupg && \
#     ln -s /usr/bin/python3 /usr/bin/python && \
#     curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
#     apt-get install -y nodejs && \
#     curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg && \
#     echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
#     apt-get update && \
#     apt-get install -y yarn && \
#     node -v && \
#     python --version && pip --version && \
#     yarn -v && \
#     git clone https://github.com/Codehackerss/hire3xide.git theia && \
#     cd theia && \
#     yarn && \
#     yarn download:plugins && \
#     yarn browser build && \
#     apt-get remove --purge -y build-essential && \
#     apt-get autoremove -y && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# # Stage 2: Runtime Stage
# FROM ubuntu:22.04

# # Install necessary runtime dependencies including Node.js, Yarn, and less
# RUN apt-get update && apt-get install -y \
#     python3 \
#     git \
#     openssh-client \
#     bash \
#     curl \
#     gnupg \
#     less && \
#     curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
#     apt-get install -y nodejs && \
#     curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg && \
#     echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
#     apt-get update && \
#     apt-get install -y yarn && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# # Create a non-root user and group named "theia"
# RUN groupadd -r theia && useradd -r -g theia -s /bin/sh -m -d /home/theia theia

# # Ensure ownership and permissions for the theia user
# RUN mkdir -p /home/theia/Project && \
#     chown -R theia:theia /home/theia && \
#     chmod -R 755 /home/theia

# # Copy only the necessary files from the build stage
# COPY --from=build /theia /home/theia/theia

# # Add a README file to the Project directory
# COPY README.md /home/theia/Project/README.md

# # Set the correct working directory for the Theia application
# WORKDIR /home/theia/theia

# # Switch to the "theia" user
# USER theia

# # Expose port 3000 for the Theia application
# EXPOSE 3000

# # Start the container by opening the README file and then launching Theia
# CMD ["sh", "-c", "less /home/theia/Project/README.md && yarn browser start --hostname 0.0.0.0"]




# //Old code And bash shell

# Stage 1: Build Stage
# FROM ubuntu:22.04 AS build

# # Install necessary build tools and dependencies
# RUN apt-get update && apt-get install -y \
#     git \
#     python3 \
#     build-essential \
#     pkg-config \
#     libx11-dev \
#     libxkbfile-dev \
#     libsecret-1-dev \
#     openjdk-17-jdk \
#     golang-go \
#     python3-setuptools \
#     python3-pip \
#     curl \
#     gnupg && \
#     ln -s /usr/bin/python3 /usr/bin/python && \
#     curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
#     apt-get install -y nodejs && \
#     curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg && \
#     echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
#     apt-get update && \
#     apt-get install -y yarn && \
#     node -v && \
#     python --version && pip --version && \
#     yarn -v && \
#     git clone https://github.com/Codehackerss/hire3xide.git theia && \
#     cd theia && \
#     yarn && \
#     yarn add -W react react-dom && \
#     yarn download:plugins && \
#     yarn browser build && \
#     apt-get remove --purge -y build-essential && \
#     apt-get autoremove -y && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# # Stage 2: Runtime Stage
# FROM ubuntu:22.04

# # Install only the necessary runtime dependencies
# RUN apt-get update && apt-get install -y \
#     python3 \
#     openjdk-17-jdk \
#     golang-go \
#     git \
#     openssh-client \
#     bash \
#     curl \
#     gnupg && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# # Install Node.js and Yarn in the runtime stage
# RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
#     apt-get install -y nodejs && \
#     curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg && \
#     echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
#     apt-get update && \
#     apt-get install -y yarn && \
#     yarn -v

# # Create a non-root user and group named "theia"
# RUN groupadd -r theia && useradd -r -g theia -s /bin/sh -m -d /home/theia theia

# # Ensure ownership and permissions for the theia user
# RUN mkdir -p /home/theia/.yarn && \
#     chown -R theia:theia /home/theia && \
#     chmod -R 755 /home/theia


#     # Configure Bash as the default shell in Theia terminal
# RUN mkdir -p /home/theia/.theia && \
# echo '{"terminal.integrated.shell.linux": "/bin/bash"}' > /home/theia/.theia/settings.json && \
# chown -R theia:theia /home/theia/.theia


# # Copy only the necessary files from the build stage
# COPY --from=build /theia /home/theia/theia

# # Set the correct working directory for the Theia application
# WORKDIR /home/theia/theia

# # Switch to the "theia" user
# USER theia

# # Expose port 3000 for the Theia application
# EXPOSE 3000

# # Start the Theia browser application
# CMD ["yarn", "browser", "start", "--hostname", "0.0.0.0"]
