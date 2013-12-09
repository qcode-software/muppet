package provide muppet 1.2.1
package require qcode
namespace eval muppet {
    namespace export *
} 

proc muppet::aolserver_install {} {
    install aolserver4-core aolserver4-nspostgres aolserver4-nssha1 daemontools daemontools-run
    sh update-rc.d -f aolserver4 remove
    user_add nsd
    file mkdir /var/log/aolserver4/
    file attributes /var/log/aolserver4/ -owner nsd -group nsd -permissions 0770
    file mkdir /var/run/aolserver4/
    file attributes /var/run/aolserver4/ -owner nsd -group nsd -permissions 0770
    # Remove logrotate config, logs will be rotated by aolserver.
    file delete /etc/logrotate.d/aolserver4-daemon
}

proc muppet::aolserver_daemontools_run { service } {
    return [subst -nocommands {#!/bin/sh
export LANG=en_GB.UTF-8
export ENVIRONMENT=`grep "ENVIRONMENT" /etc/profile | sed "s;.*= *;;"`
exec /usr/lib/aolserver4/bin/nsd -u nsd -g nsd -it /home/nsd/${service}/etc/${service}.tcl 2>&1
}]
}

proc muppet::aolserver_service {service} {
    file mkdir /var/log/aolserver4/log/$service
    file mkdir /etc/aolserver4/$service
    file_write /etc/aolserver4/$service/run [aolserver_daemontools_run $service] 0700
    file_link /etc/service/$service /etc/aolserver4/$service
}
