#!/bin/bash

# Install necessary packages
echo "Installing necessary packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y protobuf-compiler docker.io jq curl iptables build-essential git wget lz4 make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip
sudo systemctl start docker
sudo systemctl enable docker
echo "Packages installed successfully."

# Check if the directory exists
if [ -d "nexus-docker" ]; then
  echo "Directory nexus-docker already exists."
else
  mkdir nexus-docker
  echo "Directory nexus-docker created."
fi

# Navigate into the directory
cd nexus-docker

# Ask for Prover ID
read -p "Enter your Prover ID: " prover_id

# Simplified proxy input: enter proxy in format <type>://[username:password@]ip:port (leave empty if not using a proxy)
read -p "Enter proxy (format: <type>://[username:password@]ip:port) or leave empty if not using a proxy: " proxy_input

if [[ -n "$proxy_input" ]]; then
    use_proxy="Y"
    # Extract proxy type
    proxy_type=$(echo "$proxy_input" | cut -d ':' -f1)
    remainder="${proxy_input#*://}"
    # Check if credentials are provided
    if [[ "$remainder" == *"@"* ]]; then
        creds="${remainder%@*}"
        proxy_ip_port="${remainder#*@}"
        proxy_username="${creds%%:*}"
        proxy_password="${creds#*:}"
    else
        proxy_ip_port="$remainder"
        proxy_username=""
        proxy_password=""
    fi
    proxy_ip="${proxy_ip_port%%:*}"
    proxy_port="${proxy_ip_port#*:}"
    # Adjust proxy type if http is chosen
    if [[ "$proxy_type" == "http" ]]; then
        proxy_type="http-connect"
    fi
else
    use_proxy="N"
fi

# Create or replace the Dockerfile with the specified content and proxy settings
cat <<EOL > Dockerfile
FROM ubuntu:latest
# Disable interactive configuration
ENV DEBIAN_FRONTEND=noninteractive

# Update and upgrade the system
RUN apt-get update && apt-get install -y \\
    curl \\
    redsocks \\
    iptables \\
    iproute2 \\
    jq \\
    nano \\
    git \\
    build-essential \\
    wget \\
    lz4 \\
    make \\
    gcc \\
    automake \\
    autoconf \\
    tmux \\
    htop \\
    nvme-cli \\
    pkg-config \\
    libssl-dev \\
    libleveldb-dev \\
    tar \\
    clang \\
    bsdmainutils \\
    ncdu \\
    unzip \\
    ca-certificates \\
    protobuf-compiler

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:\${PATH}"

# Set up Nexus Prover ID using the user provided value
RUN mkdir -p /root/.nexus && echo "$prover_id" > /root/.nexus/prover-id
EOL

# Only add redsocks configuration and entrypoint if proxy is used
if [[ "$use_proxy" == "Y" ]]; then
    cat <<EOL >> Dockerfile
# Copy the redsocks configuration
COPY redsocks.conf /etc/redsocks.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set entrypoint to the script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EOL
fi

# Add the common CMD instruction for all cases
cat <<EOL >> Dockerfile
# Run the Nexus command and then open a shell
CMD ["bash", "-c", "curl -k https://cli.nexus.xyz/ | sh && nexus run; exec /bin/bash"]
EOL

# Create the redsocks configuration file and entrypoint script only if proxy is used
if [[ "$use_proxy" == "Y" ]]; then
    cat <<EOL > redsocks.conf
base {
    log_debug = off;
    log_info = on;
    log = "file:/var/log/redsocks.log";
    daemon = on;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = 12345;
    ip = $proxy_ip;
    port = $proxy_port;
    type = $proxy_type;
EOL

    # Append login and password if provided
    if [[ -n "$proxy_username" ]]; then
        cat <<EOL >> redsocks.conf
    login = "$proxy_username";
EOL
    fi

    if [[ -n "$proxy_password" ]]; then
        cat <<EOL >> redsocks.conf
    password = "$proxy_password";
EOL
    fi

    cat <<EOL >> redsocks.conf
}
EOL

    # Create the entrypoint script
    cat <<'EOL' > entrypoint.sh
#!/bin/sh

echo "Starting redsocks..."
redsocks -c /etc/redsocks.conf &
echo "Redsocks started."

# Give redsocks some time to start
sleep 5

echo "Configuring iptables..."
# Configure iptables to redirect HTTP and HTTPS traffic through redsocks
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 12345
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports 12345
echo "Iptables configured."

# Execute the user's command
echo "Executing user command..."
exec "$@"
EOL
fi

# Detect existing nexus-docker instances and find the highest instance number
existing_instances=$(docker ps -a --filter "name=nexus-docker-" --format "{{.Names}}" | grep -Eo 'nexus-docker-[0-9]+' | grep -Eo '[0-9]+' | sort -n | tail -1)

# Set the instance number
if [ -z "$existing_instances" ]; then
  instance_number=1
else
  instance_number=$((existing_instances + 1))
fi

# Set the container name
container_name="nexus-docker-$instance_number"

# Create a data directory for the instance
data_dir="/root/nexus-data/$container_name"
mkdir -p "$data_dir"

# Build the Docker image with the specified name
docker build -t $container_name .

# Display the completion message
echo -e "\e[32mSetup is complete. To run the Docker container, use the following command:\e[0m"
if [[ "$use_proxy" == "Y" ]]; then
    echo "docker run -it --cap-add=NET_ADMIN --name $container_name -v $data_dir:/root/.nexus $container_name"
else
    echo "docker run -it --name $container_name -v $data_dir:/root/.nexus $container_name"
fi
