# Dockerfile for ]project-open[ V5.0 on Debian 9
# See the README file for details
# Copyright (c) 2019 Iuri Sampaio <iuri@iurix.com>
# This code is provided under the GNU GPL licenses.

# this image is based on the official docker image for Debian 9
FROM debian:stretch-slim
 
# ----------------------------------------------------------------------------------
# All the data needed for the installation is provided in this image
# ----------------------------------------------------------------------------------

# the data needed to build the image
WORKDIR /usr/src/projop
COPY . /usr/src/projop

# installation script to build the image
RUN [ "/usr/src/projop/install.sh" ]

# initialization script to setup the peristent data the first time the container is run
ENTRYPOINT [ "/usr/src/projop/init.sh" ]

# command to start systemd
CMD [ "/usr/sbin/init" ]

# ----------------------------------------------------------------------------------
# Docker image configuration
# ----------------------------------------------------------------------------------

# Expose the ]project-open[ and PostgreSQL ports
EXPOSE 8000 5432

# Volume required by systemd
VOLUME [ "/sys/fs/cgroup" ]

# All persistent data is managed in a single volume
VOLUME [ "/var/lib/docker-projop/runtime" ]
