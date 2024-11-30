FROM ubuntu:20.04

# when making this image in an isolated environment (aside from the apt install) packages, we should use packages we downloaded beforehand
# like the vscode installation, dotnet installation, visual studio code server installation and so on.:

# Set non-interactive frontend to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone (adjust as needed, e.g., 'Etc/UTC' or your preferred timezone)
ENV TZ=Etc/UTC

# Install necessary packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssh-server wget curl unzip git build-essential supervisor \
    iftop tcpdump net-tools htop dstat iotop neovim nano vim tmux \
    strace lsof gdb jq bind9-dnsutils iputils-ping traceroute whois \
    zip unzip tree rsync bash-completion sudo ncdu screen python3 python3-pip && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    mkdir /var/run/sshd && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN echo "root:debugpassword" | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    echo "AllowUsers root" >> /etc/ssh/sshd_config

# Install .NET SDK (or any other SDK)
RUN wget https://dot.net/v1/dotnet-install.sh && \
    bash dotnet-install.sh --version 8.0.100 && \
    ln -s /root/.dotnet/dotnet /usr/bin/dotnet

# Install Visual Studio Code Server
RUN wget -O vscode-server.tar.gz https://update.code.visualstudio.com/latest/server-linux-x64/stable && \
    mkdir -p /root/.vscode-server && \
    tar -xzf vscode-server.tar.gz -C /root/.vscode-server --strip-components 1 && \
    rm vscode-server.tar.gz

# Install vsdbg for .NET debugging
RUN curl -sSL https://aka.ms/getvsdbgsh | bash /dev/stdin -v latest -l /root/vsdbg

# Expose SSH port
EXPOSE 22

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Default entrypoint (starts supervisor)
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]