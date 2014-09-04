package provide muppet 1.2.6
package require qcode
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
