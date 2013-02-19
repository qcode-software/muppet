package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {
    namespace export *
} 

proc muppet::naviserver_install {} {
    install naviserver-core naviserver-nsdbpg naviserver
    user_add nsd
    file mkdir /var/log/naviserver/
    file attributes /var/log/naviserver/ -owner nsd -group nsd -permissions 0770
    file mkdir /var/run/naviserver/
    file attributes /var/run/naviserver/ -owner nsd -group nsd -permissions 0770
}

proc muppet::naviserver_daemontools_run { service } {
    #| Naviserver start script which will fall-back to aolserver if Naviserver is not where expected
    return [subst -nocommands {#!/bin/sh
export LANG=en_GB.UTF-8
export ENVIRONMENT=`grep "ENVIRONMENT" /etc/profile | sed "s;.*= *;;"`
if [ -f /usr/lib/naviserver/bin/nsd ];
then
NSD_EXE=/usr/lib/naviserver/bin/nsd
else
NSD_EXE=/usr/lib/aolserver4/bin/nsd
fi
exec \$NSD_EXE -u nsd -g nsd -i -t /home/nsd/${service}/etc/${service}.tcl 2>&1
}]
}

proc muppet::naviserver_service {service} {
    file mkdir /var/log/naviserver/log/$service
    file mkdir /etc/nsd/$service
    file_write /etc/nsd/$service/run [naviserver_daemontools_run $service] 0700
    file_link /etc/service/$service /etc/nsd/$service
}
