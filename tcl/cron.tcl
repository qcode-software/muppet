package require qcode 6
namespace eval muppet {
    namespace export *
}

proc muppet::crontab {user {crontab ""}} {
    if { $crontab ne "" } {
	set filename [file_temp $crontab\n]
	sh crontab -u $user $filename
	file delete $filename
    }
    return [sh crontab -u $user -l]
}

proc muppet::crontab_delete {user} {
    sh crontab -u $user -r
}

proc muppet::crontab_office_hours {} {
    #| Returns a crontab which will run during office hours.
    #| Use for anything that's not a 24/7 server.
    return {# /etc/crontab: system-wide crontab
# Unlike any other crontab you don't have to run the `crontab'
# command to install the new version when you edit this file
# and files in /etc/cron.d. These files also have username fields,
# that none of the other crontabs do.

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# m h dom mon dow user	command
17 *	* * *	root    cd / && run-parts --report /etc/cron.hourly
25 8	* * *	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
47 8	* * 7	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
52 8	1 * *	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )
#
}
}
