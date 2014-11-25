package provide muppet 1.3.1
package require qcode
namespace eval muppet {}

proc muppet::ssh_user_private_key { user private_key {filename "id_rsa"}} {
    #| Writes a private key to disk, decrypting it if encrypted
    set ssh_path "[muppet::user_home $user]/.ssh"
    if { ![file exists $ssh_path] } {
	file mkdir $ssh_path
	file attributes $ssh_path -owner $user -group $user -permissions 0700
    }
    file_write ${ssh_path}/$filename $private_key 0600 
    file attributes ${ssh_path}/$filename -owner ${user} -group ${user} -permissions 0600
    # Is the key encrypted?
    if { [regexp -line {^Proc-Type:\s+\d,ENCRYPTED$} $private_key] } {
        # Decrypt the key on disk
        sh ssh-keygen -p -N "" -f ${ssh_path}/$filename
    }
}

proc muppet::ssh_user_public_key {user private_key} {
    set ssh_path "[muppet::user_home $user]/.ssh"
    if { ![file exists $ssh_path] } {
	file mkdir $ssh_path
	file attributes $ssh_path -owner $user -group $user -permissions 0700
    }
    file_write $ssh_path/id_rsa.pub $private_key 0600 
    file attributes $ssh_path/id_rsa.pub -owner ${user} -group ${user} -permissions 0600
}

proc muppet::ssh_user_authorize_key {user public_key} {
    if { [muppet::user_exists $user] } {
        set ssh_path "[muppet::user_home $user]/.ssh"
        if { ![file exists $ssh_path] } {
	    file mkdir $ssh_path
	    file attributes $ssh_path -owner $user -group $user -permissions 0700
        }
        if { ![file exists $ssh_path/authorized_keys] || ![file_contains_line $ssh_path/authorized_keys $public_key] } {
	    file_append ${ssh_path}/authorized_keys $public_key
	    file attributes $ssh_path/authorized_keys -owner $user -group $user -permissions 0644
        }
    } else {
        error "No such user $user"
    }
} 

proc muppet::ssh_user_config {method user host args} {
    #| Create or modify a Host clause in the user's ssh_config ~/.ssh/config
    # Each Host clause must be uniquely named
    set config_path "[muppet::user_home $user]/.ssh"
    set config_file "$config_path/config"
    if { ![file exists $config_path] } {
        sh mkdir $config_path
    }
    if { ![file exists $config_file] } {
        # config is new
        sh touch $config_file
        set config ""
    } else {
        # config exists
        set config [muppet::cat $config_file]
    }
    file_write $config_file [muppet::ssh_user_config_transform $config $method $host {*}$args]
}

proc muppet::ssh_user_config_transform {config method host args} {
    #| Transform an ssh config string
    # method one of set | update | delete

    # Parse config string into a dict with a key for global config options and a key for each host.
    # Each dict value is a multimap of config name/value pairs
    # Use #global to avoid collision with Host global
    set dict {}
    foreach line [split $config \n] {
        lassign [ssh_config_parse_line $line] name value
        if { ![info exists this_host] && [qc::lower $name] ne "host" } {
            dict lappend dict "#global" $name $value
        } else {
            if { [qc::lower $name] eq "host" } {
                # Starting a new host section
                set this_host $value
            } else {
                dict lappend dict $this_host $name $value
            }
        }        
    }
    # Set or Update or Delete
    switch $method {
        set {
            dict set dict $host $args
        }
        update {
            set multimap [dict get $dict $host]
            # Clause is being updated.
            foreach {name value} $args {
                qc::multimap_set_first -nocase multimap $name $value
            }
            dict set dict $host $multimap
        }
        delete {
            # Clause is being deleted.
            dict unset dict $host
        }
        default {
            error "Unknown method. Must be one of set, update or delete."
        }
    }
    # Format for output
    set lines {}
    dict for {key multimap} $dict {
        if {$key ne "#global"} { 
            lappend lines "Host $key"
        }
        foreach {name value} $multimap {
            if { $name eq "#comment" } {
                lappend lines "#$value"
            } elseif { $name eq "#blankline" } {
                #lappend lines ""
                # Ignore blanklines
            } else {
                lappend lines "$name $value"
            }
        }
    }
    return [join $lines \n]
}

proc muppet::ssh_config_parse_line {line} {
    # Parse one line of the config file into a name/value pairs 
    # Comments use the key "comment".
    set list {}
    if {[regexp {^\s*#(.*)$} $line -> comment]} {
        lappend list "#comment" $comment
    } elseif { [regexp {^\s*$} $line -> comment] } {
        lappend list "#blankline" ""
    } elseif { [regexp {[^=]+=[^=]+} $line] } { 
        lappend list {*}[qc::split_pair $line =]
    } else {
        lappend list {*}[qc::split_pair [string map [list \t " "] $line] " "]
    }
    return $list
}

proc muppet::ssh_private_repo { name user host } {
    #| Set up access to an ssh private repository for the root user.
    puts "Private Key remote location:"
    set key_location [gets_with_timeout 100000 ""]
    set private_key [http_get $key_location]
    set filename [file tail $key_location]
    ssh_user_private_key root $private_key $filename
    muppet::ssh_user_config set root $name HostName $host User $user IdentityFile ~/.ssh/$filename
    
    # Add to sources.list
    # What distribution is this? squeeze or wheezy?
    #
    set code_name [exec lsb_release -cs]
    set repo_source "deb ssh://${name}:/home/${user}/ $code_name main"
    if { ![file_contains_line /etc/apt/sources.list $repo_source] } {
        file_append /etc/apt/sources.list $repo_source
    }
}
