# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Set environment variables to avoid interactive prompts during package installations
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && \
    apt-get install -y \
    software-properties-common \
    build-essential \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Add deadsnakes PPA for Python 3.13
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
    python3.13 \
    python3.13-dev \
    python3.13-venv \
    python3.13-pip \
    && rm -rf /var/lib/apt/lists/*

# Install JupyterLab
RUN pip3.13 install --upgrade pip && \
    pip3.13 install jupyterlab==4.4.2

# Install NVIDIA CUDA 12.8
RUN apt-get update && \
    apt-get install -y gnupg2 curl software-properties-common && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub  | apt-key add - && \
    add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/  /" && \
    apt-get update && \
    apt-get install -y cuda-12-8 && \
    rm -rf /var/lib/apt/lists/*

# Set CUDA environment variables
ENV PATH=/usr/local/cuda-12.8/bin${PATH:+:${PATH}}
ENV LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

# Install PyTorch 2.7 with CUDA 12.8
RUN pip3.13 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 

# Set the default command to start JupyterLab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
