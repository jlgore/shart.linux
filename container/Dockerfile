FROM debian:bookworm-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color

# Install base packages and dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

# Add HashiCorp GPG key and repository
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform and other packages
RUN apt-get update && apt-get install -y \
    terraform \
    vim \
    htop \
    git \
    jq \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy MOTD
COPY assets/motd.txt /etc/motd

# Set custom hostname for shart.linux
RUN echo "shart-linux" > /etc/hostname

# Configure shell prompt to show shart.linux
RUN echo 'export PS1="[\u@shart-linux \W]$ "' >> /etc/bash.bashrc

# Display MOTD on login
RUN echo 'cat /etc/motd' >> /etc/bash.bashrc

# Create a non-root user for CTF scenarios
RUN useradd -m -s /bin/bash ctfuser && \
    echo 'ctfuser:shart123' | chpasswd

# Set working directory
WORKDIR /home/ctfuser

# Switch to ctfuser
USER ctfuser

# Display MOTD and version info on container start
CMD ["/bin/bash", "-c", "cat /etc/motd && echo 'Terraform version:' && terraform version && exec /bin/bash"]