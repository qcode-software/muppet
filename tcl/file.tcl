package provide muppet 1.1.0
package require qcode
namespace eval muppet {
    namespace export *
} 

proc muppet::file_write { filename contents {perms ""} } {
    # Return true if file has changed by writing to it.
    if { $perms ne "" } {
	set perms [qc::format_right0 $perms 5]
    }
    if { [regexp {^([^@]+)@([^:]+[^\\]):(.+)$} $filename -> username host path]} {
	if { $perms ne "" } {
	    set handle [open "| ssh $username@$host \"touch $path && chmod $perms $path && cat > $path\"" w]
	} else {
	    set handle [open "| ssh $username@$host \"cat > $path\"" w]
	}
	puts -nonewline $handle $contents
	close $handle
	return true
    } elseif { [regexp {^([^:]+[^\\]):(.+)$} $filename -> host path] } {
	if { $perms ne "" } {
	    set handle [open "| ssh $host \"touch $path && chmod $perms $path && cat > $path\"" w]
	} else {
	    set handle [open "| ssh $host \"cat > $path\"" w]
	}
	puts -nonewline $handle $contents
	close $handle
	return true
    } else {
	if { ![file exists $filename] || [cat $filename] ne $contents || [file attributes $filename -permissions]!=$perms } { 
	    puts -nonewline "writing ${filename} ..."
	    set handle [open $filename w+ 00600]
	    puts -nonewline $handle $contents
	    close $handle
	    if { $perms ne "" } {
		# set file permissions
		file attributes $filename -permissions $perms
	    }
	    puts "written"
	    return true
	} else {
	    return false
	}
    }
}

proc muppet::file_append { filename content } {
    puts "appending ${filename} ..."
    set handle [open $filename a+]
    puts $handle $content
    close $handle
    puts "...written"
}

proc muppet::file_minus_line { filename content } {
    set handle [open $filename r]
    set lines [split [read $handle] \n]
    close $handle

    set result {}
    foreach line $lines {
        if { $line != $content } {
            lappend result $line
        }
    }
    return [join $result \n]
}

proc muppet::file_contains_line { filename content } {
    set handle [open $filename r]
    set lines [split [read $handle] \n]
    close $handle

    foreach line $lines {
        if { $line == $content } {
            return true
        }
    }
    return false
}

proc muppet::file_download { url } {
    install wget
    sh wget $url 
}

proc muppet::file_regsub {args} {
    # file_regsub ?switches? exp filename subSpec ?out_filename?
    set switches {}
    set index 0
    foreach arg $args {
	if { $arg eq "--" } {
	    incr index
	    break
	} elseif { $arg in [list "-all" "-expanded" "-line" "-linestop" "-lineanchor" "-nocase" "-start"] } {
	    incr index
	    lappend switches $arg
	} else {
	    break
	}
    }
    lassign [lrange $args $index end] exp filename subSpec out_filename
    regsub {*}$switches -- $exp [cat $filename] $subSpec result
    if { $out_filename ne "" } {
	file_write $out_filename $result [file attributes $filename -permissions]
    }
    return $result
}

proc muppet::file_link { link target } {
    if { [file exists $link] } {
        file delete $link
    } 
    puts "creating link $link -> $target"
    file link $link $target
}

proc muppet::config_update {filename args} {
    #| Modify or append uniquely named config params specified as name value pairs in args.
    # Return updated config. 
    # Error if param name is not unique within config. 
    # Configs layout should be similar to:
    # param1 = value1
    # #param2 = value2
    # Usage: config_update /etc/postgresql/8.4/main/postgresql.conf shared_buffers 24MB listen_addresses "'127.0.0.1, 192.168.0.2'" 
    set config [cat $filename]    
    set append_lines {}
   
    foreach {name value} $args {
	set regexp_active [string map [list name $name] {^[ \t]*name[ \t]*([= \t])[ \t]*([^'" \t]*|['"][^'"]*['"])(.*$)}]
	set regexp_disabled [string map [list name $name] {^[ \t]*#[ \t]*name[ \t]*([= \t])[ \t]*([^'" \t]*|['"][^'"]*['"])(.*$)}]
	if { [regexp -line -all $regexp_active $config] > 1 } {
	    error "Multiple active params exist for \"$name\", name must be unique in $filename."
	} 

	if { [regexp -line $regexp_active $config] } {
	    # active parameter exists - update value.
	    regsub -line $regexp_active $config "${name}\\1${value}\\3" config
	} elseif { [regexp -line $regexp_disabled $config] } {
	    # disabled paramter exists - uncomment and update value.
	    regsub -line $regexp_disabled $config "${name}\\1${value}\\3" config
	} else {
	    # parameter doesn't exist - append to config file
            # Guess the separator by counting active lines using '='
            if { [regexp -line -all -- {(?:^[ \t]*[^#\t][^\t]+[ \t]*)=(?:[ \t]*)(?:[^'" \t]*|['"][^'"]*['"])(?:.*$)} $config]> 0 } {
                set separator "="
            } else {
                set separator " "
            }
	    if {[regexp {\r?\n[ \t]*$} $config] } {
		# config ends with a newline
		append config "${name}${separator}${value}"
	    } else {
		append config "\n${name}${separator}${value}"
	    }
	}
    }
    
    return $config
}

proc muppet::cat {filename} {
    if { [regexp {^([^@]+)@([^:]+[^\\]):(.+)$} $filename -> username host path]} {
	set handle [open "| ssh $username@$host cat $path" r]
	set contents [read $handle]
	close $handle
    } elseif { [regexp {^([^:]+[^\\]):(.+)$} $filename -> host path] } {
	set handle [open "| ssh $host cat $path" r]
	set contents [read $handle]
	close $handle
    } else {
	set handle [open $filename r]
	set contents [read $handle]
	close $handle
    }
    return $contents
}
