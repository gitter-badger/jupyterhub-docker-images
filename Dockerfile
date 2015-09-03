# This Dockerfile is based on the docker-demo-images repo(https://github.com/jupyter/docker-demo-images)
# I'm very new to Dockerfile and Jupyterhub, so there might be some mistakes.
#
FROM debian:jessie

MAINTAINER Gnimuc <gnimuckey@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y \
    git \
    vim \
    wget \
    build-essential \
    python-dev \
    ca-certificates \
    bzip2 \
    libsm6 \
    npm \
    nodejs-legacy \
    && apt-get clean

# add /opt/conda to PATH
ENV PATH /opt/conda/bin:$PATH
  
# install conda
RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    /bin/bash /Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda3-latest-Linux-x86_64.sh && \
    /opt/conda/bin/conda install --yes conda==3.14.0

# add user gnimuc and give it permission 
RUN useradd -m -s /bin/bash gnimuc
RUN chown -R gnimuc:gnimuc /opt/conda

USER gnimuc
ENV HOME /home/gnimuc
ENV SHELL /bin/bash
ENV USER gnimuc
WORKDIR $HOME

# install ipython notebook
RUN conda install --yes ipython-notebook && conda clean -yt

# create ipython profile
RUN ipython profile create

# change to root
USER root

# setup jupyter dependencies
RUN npm install -g configurable-http-proxy

# install jupyter and use default config
RUN git clone https://github.com/jupyter/jupyterhub.git /root/jupyterhub
RUN cd /root/jupyterhub/ && pip install -r requirements.txt && pip install .

# install RISE 
# we should create default path:/home/*/.jupyter/nbconfig before we install RISE
# even though jupyter will create this path automatically when we run jupyterhub and login for the first time.
RUN cd /home/gnimuc/ && mkdir .jupyter && cd .jupyter && mkdir nbconfig
RUN git clone https://github.com/damianavila/RISE.git /root/RISE
RUN cd /root/RISE/ && python setup.py install

# to fix pip permission bugs
RUN chown -R gnimuc:gnimuc /home/gnimuc/

# install extra kernels
RUN pip install bash_kernel

# change working directory to default
WORKDIR /root

# expose port 8000 which is listened by jupyterhub
EXPOSE 8000

CMD jupyterhub
