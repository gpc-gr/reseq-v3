#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

# ================================================================================
# base image
# ================================================================================

FROM debian:buster-20190506-slim AS base

# Install some packages
RUN apt update\
    && apt install -y --no-install-recommends bzip2 ca-certificates curl libpng16-16 less zip\
    && apt autoremove -y\
    && apt clean -y\
    && rm -rf /var/lib/apt/lists/*\
    && ln -s /usr/lib/x86_64-linux-gnu/libpng16.so.16 /usr/lib/x86_64-linux-gnu/libpng12.so.0

# Install Miniconda
RUN cd /tmp\
    && curl -LO https://repo.anaconda.com/miniconda/Miniconda3-4.6.14-Linux-x86_64.sh\
    && rm -rf /usr/local\
    && bash /tmp/Miniconda3-4.6.14-Linux-x86_64.sh -b -p /usr/local\
    && rm /tmp/*.sh

# Install Conda dependencies
COPY environment.yml /tmp/environment.yml
RUN /usr/local/bin/conda env update base -f /tmp/environment.yml\
    && /usr/local/bin/conda remove --force gcc_impl_linux gcc_linux gfortran_impl_linux pyqt pt\
    && /usr/local/bin/conda clean --all\
    && rm /tmp/environment.yml

# Install GATK-3.7 JAR
RUN cd /tmp\
    && curl -o GenomeAnalysisTK-3.7.tar.gz -L "https://software.broadinstitute.org/gatk/download/auth?package=GATK-archive&version=3.7-0-gcfedb67"\
    && tar xvf GenomeAnalysisTK-3.7.tar.gz GenomeAnalysisTK.jar\
    && /usr/local/bin/gatk-register GenomeAnalysisTK.jar\
    && rm GenomeAnalysisTK*

# Install UCSC wigToBigWig
RUN cd /usr/local/bin\
    && curl -LO http://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64.v369/bigWigToWig\
    && chmod +x bigWigToWig

# Set shell
ENV SHELL /bin/bash


# ================================================================================
# development image
# ================================================================================

FROM base AS dev

RUN conda install bioconda::cromwell=0.40=1 conda-forge::findutils=4.6.0=h14c3975_1000

RUN echo 'export PS1="[\u@\h \W]\# "' >> /root/.bashrc
COPY .devcontainer/settings.vscode.json /root/.vscode-remote/data/Machine/settings.json


# ================================================================================
# production image
# ================================================================================

FROM base AS prod

COPY . /opt/gpc/reseq/
