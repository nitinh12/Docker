# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV JUPYTER_PORT=8888
ENV SHELL=/bin/bash
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Set shell for build commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install basic dependencies (removed nginx)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        build-essential \
        curl \
        wget \
        git \
        libgl1 \
        locales \
    && \
    # Set locale
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    # Clean up
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python 3.13 and dependencies
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.13 \
        python3.13-dev \
        python3.13-venv \
        python3-setuptools \
        python3-wheel \
        python3.12-dev \
        libexpat1-dev \
        zlib1g-dev && \
    # Clean up
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Install pip for Python 3.13 using get-pip.py
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13 && \
    python3.13 -m pip install --upgrade pip

# Install JupyterLab and additional utilities
RUN python3.13 -m pip install --no-cache-dir \
    jupyterlab==4.4.2 \
    ipywidgets \
    jupyter-archive

# Install PyTorch with CUDA support
RUN python3.13 -m pip install --no-cache-dir \
    torch==2.7.0 \
    torchvision==0.22.0 \
    torchaudio==2.7.0 \
    --index-url https://download.pytorch.org/whl/cu128

# Create the workspace directory
RUN mkdir -p /workspace && \
    chmod -R 777 /workspace

# Create a welcome message
RUN echo "Welcome to your RunPod container!\n\
This image includes Python 3.13, JupyterLab 4.4.2, and PyTorch 2.7.0 with CUDA 12.8.\n\
JupyterLab is running on port 8888.\n\
" > /etc/runpod.txt && \
    echo 'cat /etc/runpod.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor detailed documentation, visit:\n\033[1;34mhttps://docs.runpod.io/\033[0m\n\n"' >> /root/.bashrc

# Create the startup script (simplified, removed nginx and sshd)
COPY <<EOF /start.sh
#!/bin/bash
echo "Starting container..."
# Ensure shell is available for terminal
ln -sf /bin/bash /bin/sh
# Check if port 8888 is in use
if netstat -tuln | grep -q ":8888 "; then
    echo "Port 8888 is already in use, attempting to free it..."
    fuser -k 8888/tcp || true
fi
# Start JupyterLab as root, no token, allow origin
echo "Starting JupyterLab..."
python3.13 -m jupyter lab --ip=0.0.0.0 --port=\${JUPYTER_PORT} --no-browser --allow-root --ServerApp.token="" --ServerApp.password="" --ServerApp.allow_origin="*" --ServerApp.preferred_dir=/workspace --ServerApp.terminado_settings='{"shell_command": ["/bin/bash"]}' &> /workspace/jupyter.log &
echo "JupyterLab started"
# Keep the container running
tail -f /workspace/jupyter.log
EOF

# Ensure the script is executable
RUN chmod +x /start.sh && \
    # Verify the script exists and is executable during build
    ls -l /start.sh && \
    cat /start.sh

# Set working directory to /workspace
WORKDIR /workspace

# Expose JupyterLab port
EXPOSE 8888

# Use the startup script as the entrypoint
ENTRYPOINT ["/start.sh"]
