FROM quay.io/jupyter/base-notebook:ubuntu-24.04
LABEL maintainer="Christophe Trophime <christophe.trophime@lncmi.cnrs.fr"
LABEL repo="https://github.com/Trophime/feelpp.binder"

USER root
RUN apt-get -qq update && \
    apt-get -y install coreutils tree wget gpg && \
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

USER ${NB_UID}

COPY requirements.txt /build-context/requirements.txt
WORKDIR /build-context/

RUN pip install -r requirements.txt
# Install vtk-osmesa wheel
RUN pip uninstall vtk -y
RUN pip install --no-cache-dir --extra-index-url https://wheels.vtk.org vtk-osmesa

# from pyvista tutorial
COPY . ${HOME}
WORKDIR ${HOME}
RUN pip install hypothesis lxml pyct rtree tqdm
WORKDIR $HOME

# allow jupyterlab for ipyvtk
ENV JUPYTER_ENABLE_LAB=yes
ENV PYVISTA_TRAME_SERVER_PROXY_PREFIX='/proxy/'
