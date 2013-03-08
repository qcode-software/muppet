package provide muppet 1.0
package require qcode 1.8
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
    # Each Host cluase must be uniquely named
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

doc muppet::ssh_user_config {
    Usage {set|update|delete user host ?config_name value? ?config_name value?}
    Example {
        % ssh_user_config set root muppet_repo HostName debian.qcode.co.uk User muppet IdentityFile ~/.ssh/id_muppet_rsa
        # will add the following to ~/.ssh/config in root's home dir.
        Host muppet_repo
        Hostname debian.qcode.co.uk
        User muppet
        IdentityFile ~/.ssh/id_muppet_rsa
    }
}

proc muppet::ssh_user_config_transform {config method host args} {
    #| Transform an ssh config string
    # method one of set | update | delete

    # Parse config file
    set host_ldict [muppet::ssh_user_config2ldict $config]
    # get index of host_dict
    set index [qc::ldict_search host_ldict "host" $host]
    # Extract host_dict ({} if doesn't exist)
    set host_dict [lindex $host_ldict $index]

    switch $method {
        set {
            # Clause is being set. Replace $host_clause if exists.
            set new_host_dict [dict create host $host {*}$args]
            if { $index ne -1 } {
                # host clause exists, replace
                set host_ldict [lreplace $host_ldict $index $index $new_host_dict]
            } else {
                # New host clause
                lappend host_ldict $new_host_dict
            }
        }
        update {
            # Clause is being updated. $host_clause will be changed and rewritten.
            foreach {name value} $args {
                dict set host_dict [qc::lower $name] $value
            }
            set host_ldict [lreplace $host_ldict $index $index $host_dict]
        }
        delete {
            # Clause is being deleted. $host_clause will be removed.
            set host_ldict [lreplace $host_ldict $index $index]
        }
        default {
            error "Unknown method. Must be one of set, update or delete."
        }
    }
    return [muppet::ssh_user_ldict2config $host_ldict]
}

proc muppet::ssh_user_ldict2config { host_ldict } {
    #| Will format a list of dicts as a string containing host clauses.
    set config {}
    foreach host_dict $host_ldict {
        set lines {}
        dict for {key value} $host_dict {
            lappend lines "[qc::lower $key] $value"
        }
        lappend config [join $lines \n]
    }
    return [join $config \n\n]
}

proc muppet::ssh_user_config2ldict { config } {
    #| Parse ssh_config file contents into a list of dicts.
    # Will only work with straightforward "keyword value" pairs
    # Valid config lines that will NOT work at the moment are:
    #
    # LocalForward locahost:1430  imap.pretendco.com:143 
    # UserKnownHostsFile=/dev/null
    # Port 9999 # this is a comment
    # 
    # Keyword case insensitive
    # Value case sensitive

    set host_ldict {}
    set host_dict {}
    
    foreach {keyword value} $config {
        switch [qc::lower $keyword] {
            "host" {
                if { $host_dict ne {} } {
                    # We have an existing host clause to now finish
                    lappend host_ldict $host_dict
                }
                # start of new host clause
                set host_dict [dict create [qc::lower $keyword] $value]
            }
            default {
                dict set host_dict [qc::lower $keyword] $value
            }
        }
    }
    if { $host_dict ne {} } {
        # Reached end of config, last host clause is finshed
        lappend host_ldict $host_dict
    }
    return $host_ldict
}

proc muppet::ssh_user_config2ldict2 { config } {
    # Alternate implementation
    set host_dict [dict create [qc::lower [qc::lshift config]] [qc::lshift config]]
    while { [llength $config] && [qc::lower [lindex $config 0]] ne "host" } {
        dict set host_dict [qc::lower [qc::lshift config]] [qc::lshift config]
    }
    if { [llength $config] } {
        return [list $host_dict {*}[muppet::ssh_user_config2ldict2 $config]]
    } else {    
        return [list $host_dict]
    }
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
    set repo_source "deb ssh://${name}:/home/${user}/ squeeze main"
    if { ![file_contains_line /etc/apt/sources.list $repo_source] } {
        file_append /etc/apt/sources.list $repo_source
    }
}

doc muppet::ssh_private_repo {
    Examples {
        % muppet ssh_repo_access private john debian.domain.co.uk
        Will look for an encrypted private key at a remote location and save it to /root/.ssh/
        The encrypted key will be decypted on disk requiring the encryption key to be entered by the user.
        An ssh config will be added as follows to use the saved private key to access this repo:
        
        Host private
        HostName debian.domain.co.uk
        User john
        IdentityFile ~/.ssh/john.key
        
        and a sources.list entry will be added
        deb ssh://private:/home/john/ squeeze main

        Assume that this key has already been authorized access to john@debian.domain.co.uk
    }
}
