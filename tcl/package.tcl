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

proc muppet::locale_set { locale charset } {
    #| Sets system default locale
    # Usage: muppet::locale_set en_GB.UTF-8 UTF-8
    # Assumes only 1 locale will be generated
    # Note preseed options arent working at the moment: http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=684134
    # so performing the update manually rather than by doing:
    # package_option locales locales/default_environment_locale select $locale
    # package_option locales locales/locales_to_be_generated multiselect "$locale $charset"
    # dpkg-reconfigure -f noninteractive locales
   
    # Open the locale.gen file to populate with the correct selections
    set locale_gen [list {# This file lists locales that you wish to have built. You can find a list}]
    lappend locale_gen {# of valid supported locales at /usr/share/i18n/SUPPORTED, and you can add}
    lappend locale_gen {# user defined locales to /usr/local/share/i18n/SUPPORTED. If you change}
    lappend locale_gen {# this file, you need to rerun locale-gen.}
    lappend locale_gen {}
    lappend locale_gen {}

    set supported_locales [muppet::cat "/usr/share/i18n/SUPPORTED"]

    foreach supported_locale [split $supported_locales \n] {
        if { "$locale $charset" eq $supported_locale } {
            # Add selected locale to be generated
            lappend locale_gen "$supported_locale"
        } else {
            # Add nonselected locales commented out
            lappend locale_gen "# $supported_locale"
        }
    }
    muppet::file_write "/etc/locale.gen" [join $locale_gen \n]

    # Generate selected locale
    sh locale-gen

    # Unset default LANG
    sh update-locale --no-checks LANG

    # Set the default LANG
    sh update-locale "LANG=${locale}"
}

