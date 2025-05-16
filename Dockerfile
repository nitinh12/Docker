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

# Install basic dependencies (aligned with RunPod official templates)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        build-essential \
        curl \
        wget \
        git \
        libgl1 \
        openssh-server \
        nginx \
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

# Set up SSH (optional, for RunPod compatibility)
RUN mkdir /var/run/sshd && \
    rm -f /etc/ssh/ssh_host_* && \
    ssh-keygen -A

# Nginx proxy configuration (optional, for better RunPod integration)
RUN echo "worker_processes 1;\n\
events { worker_connections 1024; }\n\
http {\n\
    server {\n\
        listen 8888;\n\
        location / {\n\
            proxy_pass http://127.0.0.1:8888;\n\
            proxy_set_header Host \$host;\n\
            proxy_set_header X-Real-IP \$remote_addr;\n\
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n\
            proxy_set_header X-Forwarded-Proto \$scheme;\n\
        }\n\
    }\n\
}" > /etc/nginx/nginx.conf && \
    echo "<html><body><h1>Welcome to RunPod</h1><p>Access JupyterLab at this URL.</p></body></html>" > /usr/share/nginx/html/readme.html

# Create a welcome message
RUN echo "Welcome to your RunPod container!\n\
This image includes Python 3.13, JupyterLab 4.4.2, and PyTorch 2.7.0 with CUDA 12.8.\n\
JupyterLab is running on port 8888.\n\
" > /etc/runpod.txt && \
    echo 'cat /etc/runpod.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor detailed documentation, visit:\n\033[1;34mhttps://docs.runpod.io/\033[0m\n\n"' >> /root/.bashrc

# Create a startup script for JupyterLab
RUN echo '#!/bin/bash\n\
echo "Starting container..."\n\
# Ensure shell is available for terminal\n\
ln -sf /bin/bash /bin/sh\n\
# Start Nginx for proxy\n\
nginx &\n\
# Start SSH server (optional)\n\
/usr/sbin/sshd &\n\
# Start JupyterLab as root, no token, allow origin\n\
echo "Starting JupyterLab..."\n\
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
echo "JupyterLab started"' > /start.sh && \
    chmod +x /start.sh

# Set working directory to /workspace
WORKDIR /workspace

# Expose JupyterLab port
EXPOSE 8888

# Use the startup script as the entrypoint
ENTRYPOINT ["/start.sh"]
