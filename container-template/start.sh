#!/bin/bash
set -e  # Exit the script if any statement returns a non-true return value

# ---------------------------------------------------------------------------- #
#                          Function Definitions                                #
# ---------------------------------------------------------------------------- #

# Start nginx service
start_nginx() {
    echo "Starting Nginx service..."
    service nginx start
}

# Execute script if exists
execute_script() {
    local script_path=$1
    local script_msg=$2
    if [[ -f ${script_path} ]]; then
        echo "${script_msg}"
        bash ${script_path}
    fi
}

# Setup ssh
setup_ssh() {
    if [[ $PUBLIC_KEY ]]; then
        echo "Setting up SSH..."
        mkdir -p ~/.ssh
        echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh

         if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
            ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -q -N ''
            echo "RSA key fingerprint:"
            ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub
        fi

        if [ ! -f /etc/ssh/ssh_host_dsa_key ]; then
            ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -q -N ''
            echo "DSA key fingerprint:"
            ssh-keygen -lf /etc/ssh/ssh_host_dsa_key.pub
        fi

        if [ ! -f /etc/ssh/ssh_host_ecdsa_key ]; then
            ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -q -N ''
            echo "ECDSA key fingerprint:"
            ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key.pub
        fi

        if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
            ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -q -N ''
            echo "ED25519 key fingerprint:"
            ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
        fi

        service ssh start

        echo "SSH host keys:"
        for key in /etc/ssh/*.pub; do
            echo "Key: $key"
            ssh-keygen -lf $key
        done
    fi
}

# Export env vars
export_env_vars() {
    echo "Exporting environment variables..."
    printenv | grep -E '^RUNPOD_|^PATH=|^_=' | awk -F = '{ print "export " $1 "=\"" $2 "\"" }' >> /etc/rp_environment
    echo 'source /etc/rp_environment' >> ~/.bashrc
}

# Start jupyter lab
start_jupyter() {
    if [[ $JUPYTER_PASSWORD ]]; then
        echo "Starting Jupyter Lab..."
        mkdir -p /workspace && \
        cd / && \
        nohup jupyter lab --allow-root --no-browser --port=8888 --ip=* --FileContentsManager.delete_to_trash=False --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' --ServerApp.token=$JUPYTER_PASSWORD --ServerApp.allow_origin=* --ServerApp.preferred_dir=/workspace &> /jupyter.log &
        echo "Jupyter Lab started"
    fi
}

setup_dns_and_start_cloudflare_tunnel() {
    # Set up DNS using Cloudflare's DNS servers
    echo "Setting up DNS..."
    echo -e "nameserver 1.1.1.1\nnameserver 1.0.0.1" | tee /etc/resolv.conf > /dev/null

    # Check if DNS setup was successful
    if ! grep -q "nameserver 1.1.1.1" /etc/resolv.conf || ! grep -q "nameserver 1.0.0.1" /etc/resolv.conf; then
        echo "Error: Failed to set up DNS"
        return 1
    fi

    # Start Cloudflare tunnel
    if [[ -z "$GPU_TOKEN_ID" ]]; then
        echo "Error: GPU_TOKEN_ID is not set"
        return 1
    fi

    echo "Checking if Cloudflare tunnel already exists..."
    if cloudflared tunnel list | grep -q "$GPU_TOKEN_ID"; then
        echo "Tunnel $GPU_TOKEN_ID already exists. Skipping creation."
    else
        echo "Creating Cloudflare tunnel..."
        cloudflared tunnel create "$GPU_TOKEN_ID" || {
            echo "Failed to create tunnel. Exiting."
            return 1
        }
    fi

    echo "Setting up DNS route..."
    cloudflared tunnel route dns "$GPU_TOKEN_ID" "${GPU_TOKEN_ID}.loopin.cloud"

    echo "Starting Cloudflare tunnel..."
    nohup cloudflared tunnel --name "$GPU_TOKEN_ID" --url http://127.0.0.1:8888 > /cloudflared.log 2>&1 &

    # Wait for the Cloudflare URL to be generated
    while true; do
        if grep -q "${GPU_TOKEN_ID}.loopin.cloud" /cloudflared.log; then
            CLOUDFLARE_URL="https://${GPU_TOKEN_ID}.loopin.cloud"
            export CLOUDFLARE_URL
            echo "Cloudflare URL: $CLOUDFLARE_URL"
            break
        fi
        sleep 1
    done
}


# ---------------------------------------------------------------------------- #
#                               Main Program                                   #
# ---------------------------------------------------------------------------- #

start_nginx

execute_script "/pre_start.sh" "Running pre-start script..."

echo "Pod Started"

setup_ssh
start_jupyter
setup_dns_and_start_cloudflare_tunnel
export_env_vars

execute_script "/post_start.sh" "Running post-start script..."

echo "Start script(s) finished, pod is ready to use."

sleep infinity
