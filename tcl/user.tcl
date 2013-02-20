package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {
    namespace export *
} 

proc muppet::user_exists { user } {
   if { [catch {::exec grep "^$user:" /etc/passwd}] } {
       return false
   } {
       return true
   }
}

proc muppet::user_add { args } {
    qc::args $args -type user -- user
    set options [list]
    switch $type {
	user {
	    # regular user account
	    lappend options --create-home
	    lappend options --shell /bin/bash
	}
	system {
	    # system account
	    lappend options --system
	}
	default {
	    error "Unknown user type \"$type\""
	}
    }
    if { ![user_exists $user] } {
        sh useradd {*}$options $user
    } else {
        puts "user $user already exists"
    }
}

proc muppet::user_groups { user args } {
    # user ?groups?
    if { [llength $args]!=0 } {
        foreach group $args {
            group_add $group
        }
        # set groups
        sh usermod -G [join $args ","] $user
    }
    return [::exec groups $user | sed "s/$user *: *//g"]
}

proc muppet::user_home { user } { 
    #| Return home directory of user
    return [exec su -l -c pwd $user]
}
