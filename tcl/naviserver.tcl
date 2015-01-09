package require qcode 6
namespace eval muppet {
    namespace export *
} 

proc muppet::naviserver_install {} {
    file_write /etc/default/naviserver [muppet::naviserver_defaults]
    user_add nsd
    file mkdir /var/log/naviserver/
    file attributes /var/log/naviserver/ -owner nsd -group nsd -permissions 0770
    file mkdir /var/run/naviserver/
    file attributes /var/run/naviserver/ -owner nsd -group nsd -permissions 0770
    install naviserver naviserver-core naviserver-nsdbpg naviserver-nsssl
    sh update-rc.d -f naviserver remove
}

proc muppet::naviserver_upgrade {} {
    #| Upgrades naviserver to latest version while not disturbing a daemontools config
    file_write /etc/default/naviserver [muppet::naviserver_defaults]
    sh apt-get install -y naviserver naviserver-core naviserver-nsdbpg 
    sh update-rc.d -f naviserver remove
}

proc muppet::naviserver_daemontools_run { args } {
    #| Naviserver start script
    qc::args $args -proxy "" -- service 
    set result {#!/bin/sh
export LANG=en_GB.UTF-8
export ENVIRONMENT=`grep "ENVIRONMENT" /etc/profile | sed "s;.*= *;;"`
$proxy_vars
RUNDIR=/var/run/naviserver
[ ! -d $RUNDIR ] && mkdir -p -m 755 $RUNDIR && chown nsd:nsd $RUNDIR
NSD_EXE=/usr/lib/naviserver/bin/nsd
exec $NSD_EXE -u nsd -g nsd -i -t /home/nsd/$service/etc/nsd.tcl 2>&1
}
    set proxy_vars [list]
    if { $proxy ne "" } {
        lappend proxy_vars "export http_proxy=$proxy"
        lappend proxy_vars "export https_proxy=$proxy"
        lappend proxy_vars "export HTTP_PROXY=$proxy"
        lappend proxy_vars "export HTTPS_PROXY=$proxy"
    }
    set result [string map [list \$service $service] $result]
    set result [string map [list \$proxy_vars [join $proxy_vars \n]] $result]
    return $result
}

proc muppet::naviserver_service { args } {
    qc::args $args -proxy "" -- service
    file mkdir /etc/nsd/$service
    file_write /etc/nsd/$service/run [naviserver_daemontools_run -proxy $proxy $service] 0700
    file delete /etc/service/$service
    file_link /etc/service/$service /etc/nsd/$service
}

proc muppet::naviserver_defaults {} {
    return {#
# These variables can be customized to change main Naviserver settings.
# More changes can be done by modifying the /etc/naviserver/default.tcl Tcl script.
# 
# Note that these variables are read and interpreted by the Tcl script
# too, so avoid using shell capabilities in setting vars.
#

#USER=www-data
#GROUP=www-data
# When AUTOSTART is set to all, using DAEMONTOOLS, all instances in DAEMONTOOLS_SVCDIR
# will be started/stopped/restarted, otherwise all /etc/naviserver/*.tcl config files will
# be started.
#AUTOSTART=all
#AUTOSTART="instance1 instance2"
#AUTOSTART=none

# IMPORTANT: If using Daemontools to control the Naviserver daemon, remove the init script links
# to the package script using "update-rc.d -f naviserver remove"
DAEMONTOOLS=yes
DAEMONTOOLS_SVCDIR=/etc/service
DAEMONTOOLS_SVC=/usr/bin/svc
# If set, the init script assumes the following commands are configured to work correctly:
# svc -u /instance"
# svc -t /instance"
# svc -d /instance"
# Using allows for non-standard configurations to be specificied in the DAEMONTOOLS_SVCDIR
# run script for the instance.
}
}

