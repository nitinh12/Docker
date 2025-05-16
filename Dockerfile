# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV JUPYTER_PORT=8888
ENV SHELL=/bin/bash

# Install basic dependencies
RUN apt-get update && \
    apt-get install -y \
        software-properties-common \
        build-essential \
        curl \
        wget \
        git \
        openssh-server \
        && \
    rm -rf /var/lib/apt/lists/*

# Install Python 3.13 and dependencies
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
        python3.13 \
        python3.13-dev \
        python3.13-venv \
        python3-setuptools \
        python3-wheel \
        python3.12-dev \
        libexpat1-dev \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/* && \
    # Install pip for Python 3.13 using get-pip.py
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13 && \
    python3.13 -m pip install --upgrade pip

# Install JupyterLab
RUN python3.13 -m pip install jupyterlab==4.4.2

# Install PyTorch with CUDA support
RUN python3.13 -m pip install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu128

# Create the workspace directory
RUN mkdir -p /workspace && \
    chmod -R 777 /workspace

# Create a startup script for JupyterLab
RUN echo '#!/bin/bash\n\
echo "Starting JupyterLab..."\n\
# Ensure shell is available for terminal\n\
ln -sf /bin/bash /bin/sh\n\
# Start JupyterLab as root, no token, allow origin\n\
python3.13 -m jupyter lab \
    --ip=0.0.0.0 \
    --port=${JUPYTER_PORT} \
    --no-browser \
    --allow-root \
    --ServerApp.token="" \
    --ServerApp.password="" \
    --ServerApp.allow_origin="*" \
    --ServerApp.preferred_dir=/workspace \
    --ServerApp.terminado_settings="{\"shell_command\": [\"/bin/bash\"]}" \
    &> /workspace/jupyter.log &\n\
echo "JupyterLab started"' > /start_jupyter.sh && \
    chmod +x /start_jupyter.sh

# Set working directory to /workspace
WORKDIR /workspace

# Expose JupyterLab port
EXPOSE 8888

# Use the startup script as the entrypoint
ENTRYPOINT ["/start_jupyter.sh"]
