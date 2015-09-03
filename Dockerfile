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
    curl \
    && apt-get clean

# add /opt/conda to PATH
ENV PATH /opt/conda/bin:$PATH
  
# install conda
RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    /bin/bash /Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda3-latest-Linux-x86_64.sh && \
    /opt/conda/bin/conda install --yes conda==3.14.0

# install julia v0.4 system-wide 
RUN mkdir -p /opt/julia_0.4.0 && \
    curl -s -L https://status.julialang.org/download/linux-x86_64 | tar -C /opt/julia_0.4.0 -x -z --strip-components=1 -f -
RUN ln -sf /opt/julia_0.4.0/bin/julia /usr/local/bin/
# make a julia global packages directory and add it to LOAD_PATH
RUN mkdir /opt/global-packages
RUN echo 'push!(LOAD_PATH, "/opt/global-packages/.julia/v0.4/")' >> /opt/julia_0.4.0/etc/julia/juliarc.jl
ENV JULIA_PKGDIR /opt/global-packages/.julia/

RUN groupadd jupyter

# add user gnimuc and give it permission 
RUN useradd -m -s /bin/bash gnimuc
RUN chown -R gnimuc:jupyter /opt/conda

USER gnimuc
ENV HOME /home/gnimuc
ENV SHELL /bin/bash
ENV USER gnimuc
WORKDIR $HOME

# install ipython notebook
RUN conda install --yes ipython-notebook && conda clean -yt

# create ipython profile
RUN ipython profile create

# change back to root
USER root

# setup jupyter dependencies
RUN npm install -g configurable-http-proxy

# install jupyter and use the default config
RUN git clone https://github.com/jupyter/jupyterhub.git /root/jupyterhub
RUN cd /root/jupyterhub/ && pip install -r requirements.txt && pip install .
# generate jupyterhub_config.py and enable admin to add users
RUN cd /root/ && jupyterhub --generate-config
RUN cd /root/ && echo 'c.LocalAuthenticator.create_system_users = True' > /root/jupyterhub_config.py

# install "IJulia" system-wide
RUN julia -e 'Pkg.init()'
RUN julia -e 'Pkg.add("IJulia")'
# move kernelspec from gnimuc's ipython to jupyter
RUN jupyter kernelspec list
# move kernelspec from gnimuc's jupyter to global jupyter
RUN cd /usr/local/share/ && mkdir -p jupyter/kernels/
RUN cp -r /home/gnimuc/.local/share/jupyter/kernels/julia-0.4 /usr/local/share/jupyter/kernels/

# install RISE 
# we should create default path:/home/*/.jupyter/nbconfig before we install RISE
# even though jupyter will create this path automatically when we run jupyterhub and login for the first time.
RUN cd /home/gnimuc/ && mkdir -p .jupyter && cd .jupyter && mkdir -p nbconfig
RUN git clone https://github.com/damianavila/RISE.git /root/RISE
RUN cd /root/RISE/ && python setup.py install

# to fix pip permission bugs
RUN chown -R gnimuc:jupyter /home/gnimuc/

# install extra kernels
RUN pip install bash_kernel

# change working directory to default
WORKDIR /root

# expose port 8000 which is listened by jupyterhub
EXPOSE 8000

CMD jupyterhub
