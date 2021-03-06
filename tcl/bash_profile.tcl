namespace eval muppet {}

proc muppet::bash_profile {args} {
    qc::args $args -proxy "" -- environment
    set profile "# /etc/profile: system-wide .profile file for the Bourne shell (sh(1))
# and Bourne compatible shells (bash(1), ksh(1), ash(1), ...).
	
export ENVIRONMENT=$environment
"
    if {$proxy ne ""} {
        set proxy_clause [list "export http_proxy=$proxy"]
        lappend proxy_clause "export https_proxy=$proxy"
        lappend proxy_clause ""
    } else {
        set proxy_clause ""
    }
    append profile [join $proxy_clause \n]
    append profile {if [ "`id -u`" -eq 0 ]; then
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
else
  PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
fi
export PATH

if [ "$PS1" ]; then
  if [ "$BASH" ]; then
    if [ -f /etc/bash.bashrc ]; then
      . /etc/bash.bashrc
    fi
  else
    if [ "`id -u`" -eq 0 ]; then
      PS1='# '
    else
      PS1='$ '
    fi
  fi
fi

if [ -d /etc/profile.d ]; then
  for i in /etc/profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi

}

if { ![string match DEV* $environment] } {
    append profile {TMOUT=900
readonly TMOUT
export TMOUT

}
}

    return $profile
}

proc muppet::bash_profile_install {args} {
    qc::args $args -proxy "" --
    global env
    if { ![info exists env(ENVIRONMENT)] } { 
	puts "Please Enter The Environment To Be Installed {DEV TESTING STAGING LIVE}:"
	gets stdin input
	while { ![string match DEV* $input] && $input ne "TESTING" && $input ne "LIVE" && $input ne "STAGING"} {
	    puts "Invalid Environment \"${input}\"{DEV TESTING STAGING LIVE}:"	
	    gets stdin input
	}
	set env(ENVIRONMENT) $input
    }
       
    file_write /etc/profile [bash_profile -proxy $proxy $env(ENVIRONMENT)] 0644
    puts "installed /etc/profile"
}
