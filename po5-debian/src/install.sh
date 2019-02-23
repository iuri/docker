#!/bin/sh -e
# installation script for po5-debian 9
# See the README file for details
# Copyright (c) 2018 Iuri Sampaio <iuri@iurix.com>
# This code is provided under the GNU GPL licenses.

set +e
# comment out to debug
#set -x

# ----------------------------------------------------------------------------------------------
# Script to install ]project-open[ V5.0 in a Docker image for Denbian 9
# ----------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------
# Enable systemd
# ----------------------------------------------------------------------------------------------

(
	cd /lib/systemd/system/sysinit.target.wants/
	for i in *; do
		[ "$i" == systemd-tmpfiles-setup.service ] || rm -f "$i"
	done
)
rm -f /lib/systemd/system/multi-user.target.wants/*
rm -f /etc/systemd/system/*.wants/*
rm -f /lib/systemd/system/local-fs.target.wants/*
rm -f /lib/systemd/system/sockets.target.wants/*udev*
rm -f /lib/systemd/system/sockets.target.wants/*initctl*
rm -f /lib/systemd/system/basic.target.wants/*
# rm -f /lib/systemd/system/anaconda.target.wants/*

# ----------------------------------------------------------------------------------------------
# Update repository info and installed packages
# (maybe the base image was created long time ago)
# ----------------------------------------------------------------------------------------------
apt-get -y update

# ----------------------------------------------------------------------------------------------
# Install packages required by project-open
# ----------------------------------------------------------------------------------------------

# basic administration tools required by project-open
ln -s /usr/bin/dot /usr/local/bin/dot
apt-get install -y net-tools git-core emacs unzip zip make nginx ldap-utils ghostscript gsfonts imagemagick graphviz libreoffice-writer libreoffice-draw libreoffice-java-common wget cvs htmldoc

# ----------------------------------------------------------------------------------------------
# Create user projop
# ----------------------------------------------------------------------------------------------

# super-directory for all Web servers /web/ by default
mkdir -p /web && mkdir -p /web/projop 
# create a group called "projop"
groupadd projop
# create user "projop" with home directory /web/projop
useradd -d /web/projop -g projop -m -s /bin/bash projop
# assign ownership to projop user on projop directory 
chown -R projop:projop /web/projop/

# ----------------------------------------------------------------------------------------------
# Install and setup PostgreSQL 9.2
# ----------------------------------------------------------------------------------------------

# install the required packages
# postgresql-libs will be automatically installed
apt-get install -y libpq5 postgresql-9.6 postgresql-client-9.6 postgresql-client-common postgresql-common postgresql-contrib-9.6 ssl-cert postgresql-doc postgresql-doc-9.6 libdbd-pg-perl libdbi-perl sysstat


su - postgres  <<_EOT_
# initialize the database cluster
/usr/bin/pg_ctl -D "/var/lib/pgsql/data" -l /var/lib/pgsql/initdb.log initdb
# Enable remote connections
echo "host all  all    0.0.0.0/0  md5" >> /var/lib/pgsql/data/pg_hba.conf
echo "listen_addresses='*'" >> /var/lib/pgsql/data/postgresql.conf
# start the database
/usr/bin/pg_ctl -D "/var/lib/pgsql/data" -l /var/lib/pgsql/install.log start
sleep 2
# database user "projop" with admin rights
createuser -s projop
_EOT_

# ----------------------------------------------------------------------------------------------
# Initialize the projop database
# ----------------------------------------------------------------------------------------------

su - projop  <<_EOT_
createdb --encoding=utf8 --owner=projop projop
_EOT_

# Configure PostgreSQL start with server start
systemctl enable postgresql

# ----------------------------------------------------------------------------------------------
# Install the naviserver distribution
# ----------------------------------------------------------------------------------------------

cd /usr/local
# extract the NaviServer binary 64 bit
tar xzf /usr/src/projop/naviserver-4.99.8.tgz
# fix ownerships and permissions
chown -R root:projop /usr/local/ns
chown nobody:projop /usr/local/ns/logs
find /usr/local/ns -type f -exec chmod 0664 {} \;
chmod 0775 /usr/local/ns/bin/*

# ----------------------------------------------------------------------------------------------
# Setup the /web/projop folder
# ----------------------------------------------------------------------------------------------

su - projop <<_EOT_
cd /web/projop
# extract auxiliary files
tar xzf /usr/src/projop/web_projop-aux-files.5.0.0.0.0.tgz
# extract the ]po[ product source code - latest
tar xzf /usr/src/projop/project-open-Update-5.0.2.4.0.tgz
# enable PlPg/SQL, may already be installed
#createlang plpgsql projop
psql -f /web/projop/pg_dump.5.0.2.4.0.sql > /web/projop/import.log 2>&1
_EOT_

# ----------------------------------------------------------------------------------------------
# Automate NaviServer Startup
# ----------------------------------------------------------------------------------------------

cp /usr/src/projop/projop.service /usr/lib/systemd/system
systemctl enable projop.service

# ----------------------------------------------------------------------------------------------
# Configure Automatic Backups
# ----------------------------------------------------------------------------------------------

# install the backup script in /root/bin/export-dbs
mkdir /root/bin
cp /usr/src/projop/export-dbs /root/bin
chmod ug+x /root/bin/export-dbs

# create a /var/backup directory for ]project-open[ database backups
mkdir /var/backup
chown projop:postgres /var/backup
chmod g+w /var/backup

# create a /var/log/postgres directory for ]project-open[ database related logs
mkdir /var/log/postgres
chown postgres:postgres /var/log/postgres
chmod g+w /var/log/postgres

# install a cron script to automate the backups
cp /usr/src/projop/crontab /root/bin
crontab /root/bin/crontab

# ----------------------------------------------------------------------------------------------
# Setup the directory to hold all the persistent data
# ----------------------------------------------------------------------------------------------

PODATA=/var/lib/docker-projop

mkdir "$PODATA"
mkdir "$PODATA/runtime"

setup_path() {
	local src dst dir
	dst="$PODATA/runtime/$1"
	dir=$( dirname "$dst" )
	src="$2"

	mkdir -p "$dir"
	mv "$src" "$dst"
	ln -s "$dst" "$src"
}

# project-open related volumes (configuration, filestorage and logs)
setup_path projop/etc		/web/projop/etc
setup_path projop/filestorage	/web/projop/filestorage
setup_path projop/log		/web/projop/log

# PostgreSQL related volumes (everything contained in a single path)
setup_path postgresql	/var/lib/pgsql

# Automatic backups related volumes (backup databases and logs)
setup_path backups/data	/var/backup
setup_path backups/logs	/var/log/postgres

# Save the initial persistent data
touch "$PODATA/runtime/.initialized"
tar -czf "$PODATA/initial.tar.gz" -C "$PODATA/runtime" .

# The docker documentation says that, on Windows platforms,
# mounted volumes must be non-existent or empty
rm -rf "$PODATA/runtime"
mkdir "$PODATA/runtime"

