ARG ROOT_CONTAINER=ubuntu:24.04
ARG USERNAME=vscode
ARG USER_UID=1001
ARG USER_GID=1001

FROM $ROOT_CONTAINER
LABEL maintainer="Christophe Trophime <christophe.trophime@lncmi.cnrs.fr"
LABEL repo="https://github.com/Trophime/feelpp.binder"

# Fix: https://github.com/hadolint/hadolint/wiki/DL4006
# Fix: https://github.com/koalaman/shellcheck/wiki/SC3014
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# add feelp user

RUN useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    # [Optional] Add sudo support for the non-root user
    apt-get install -y sudo && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    # add github ssh key
    mkdir -p ~$USERNAME/.ssh/ && \
    ssh-keyscan github.com >> ~$USERNAME/.ssh/known_hosts && \
    chown -R $USER_UID.$USER_GID ~$USERNAME/.ssh

RUN apt-get -qq update && \
    apt-get -y install coreutils tree wget gpg && \
    apt-get -y install mesa-utils libglx-mesa0 xvfb && \
    wget -qO - http://apt.feelpp.org/apt.gpg | apt-key add - && \
    echo "deb http://apt.feelpp.org/ubuntu/noble noble latest" | tee -a /etc/apt/sources.list.d/feelpp.list && \
    rm -f feelpp.gpg && \
    apt -qq update && \
    apt-get -y install python3-petsc4py && \
    apt-get -y install  --no-install-recommends \
               python3-feelpp-toolboxes-coefficientformpdes \
       	       python3-feelpp-toolboxes-thermoelectric \
	       python3-feelpp-toolboxes-electric \
	       python3-feelpp-toolboxes-heat && \
    apt-get -y install --no-install-recommends feelpp-quickstart feelpp-tools feelpp-data

# Install all OS dependencies for the Server that starts
# but lacks all features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update --yes && \
    # - `apt-get upgrade` is run to patch known vulnerabilities in system packages
    #   as the Ubuntu base image is rebuilt too seldom sometimes (less than once a month)
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    # - bzip2 is necessary to extract the micromamba executable.
    bzip2 \
    ca-certificates \
    locales \
    # - `netbase` provides /etc/{protocols,rpc,services}, part of POSIX
    #   and required by various C functions like getservbyname and getprotobyname
    #   https://github.com/jupyter/docker-stacks/pull/2129
    netbase \
    sudo \
    # - `tini` is installed as a helpful container entrypoint,
    #   that reaps zombie processes and such of the actual executable we want to start
    #   See https://github.com/krallin/tini#why-tini for details
    tini \
    wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    echo "C.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen

# Install python (nb feelpp is already installed)
RUN apt-get update --yes && \
    apt-get upgrade && \ 
    apt-get -y install python-is-python3 python3-venv python3-xvfbwrapper && \
    apt-get -y install libpci3 mesa-utils libegl1 libegl1-mesa-dev libxrender1 xvfb && \
    apt-get -y install nodejs nmap && \
    apt-get -y install wget curl gpg sudo
    
# eventually add a web browser
# RUN apt-get -y install firefox-esr 

# Configure environment
ENV SHELL=/bin/bash \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8
ENV PATH="/home/feelpp/jupyterlab-env/bin:${PATH}" \
    HOME="/home/feelpp"
    

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
# hadolint ignore=SC2016
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# JUPYTER_TOKEN=token
ENV JUPYTER_PORT=8888
EXPOSE $JUPYTER_PORT


# setup virtualenv for jupyter
RUN mkdir -p /home/jupyterlab-env && \
    python3 -m venv --system-site-packages /home/jupyterlab-env && \
    . /home/jupyterlab-env/bin/activate && \
    python3 -m pip install jupyterhub jupyterlab nbclassic notebook jupyter-server-proxy trame-jupyter-extension \
    	    pyvista[all] \
    	    gmsh && \
    jupyter server --generate-config && \
    jupyter lab clean && \
    deactivate


# Copy local files as late as possible to avoid cache busting
#COPY run-hooks.sh start.sh /usr/local/bin/
COPY run-hooks.sh /usr/local/bin/

# Create dirs for startup hooks
RUN mkdir /usr/local/bin/start-notebook.d && \
    mkdir /usr/local/bin/before-notebook.d


# Switch back to jovyan to avoid accidental container runs as root
USER feelpp
COPY start-venv.sh ${HOME}
COPY examples ${HOME}/examples
# COPY start ${HOME}

WORKDIR "${HOME}"

# Configure container entrypoint
ENTRYPOINT ["tini", "-g", "--", "./start-venv.sh"]

