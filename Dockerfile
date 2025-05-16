# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install basic dependencies
RUN apt-get update && \
    apt-get install -y \
        software-properties-common \
        build-essential \
        curl \
        wget \
        git && \
    rm -rf /var/lib/apt/lists/*

# Install Python 3.13 and pip
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
        python3.13 \
        python3.13-dev \
        python3.13-venv \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3.12-dev \
        libexpat1-dev \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/* && \
    python3.13 -m ensurepip --upgrade && \
    python3.13 -m pip install --upgrade pip

# Install JupyterLab
RUN python3.13 -m pip install jupyterlab==4.4.2

# Install PyTorch with CUDA support
RUN python3.13 -m pip install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu128

# Set working directory
WORKDIR /app

# Expose JupyterLab port
EXPOSE 8888

# Command to run JupyterLab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--allow-root", "--no-browser"]
