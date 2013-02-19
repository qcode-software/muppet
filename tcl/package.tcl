package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {
    namespace export *
} 

proc muppet::installed { pkg } {
    # dpkg returns 3 values for a package status which are: selection-status flags current-status
    # eg. install ok installed
    if { ![catch [list ::exec dpkg-query -W -f=\${Status} $pkg] result] && [lindex $result 2] eq "installed" } {
	return true
    } else {
	return false
    }
}

proc muppet::install { args } {
    args $args -release ? -- args
    foreach pkg $args {
	if { ![installed $pkg] } {
            set ::env(DEBIAN_FRONTEND) noninteractive
            set options {}
            if { [info exists release] } {
	        sh apt-get --target-release $release install -y $pkg
            } else {
	        sh apt-get install -y $pkg
            }
	} else {
	    puts "$pkg already installed"
	}
    }
}

proc muppet::deinstall { args } {
    foreach pkg $args {
	if { [installed $pkg] } {
	    sh apt-get remove -y --purge $pkg
	} else {
	    puts "$pkg not installed"
	}
    }
}

proc muppet::package_option {owner question_name question_type value} {
    sh debconf-set-selections << "$owner $question_name $question_type $value"
}
