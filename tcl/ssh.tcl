package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {}

proc muppet::ssh_user_private_key { user private_key {keyname "id_rsa"}} {
    #| Writes a private key to disk, decrypting it if encrypted
    set ssh_path "[muppet::user_home $user]/.ssh"
    if { ![file exists $ssh_path] } {
	file mkdir $ssh_path
	file attributes $ssh_path -owner $user -group $user -permissions 0700
    }
    file_write ${ssh_path}/$keyname $private_key 0600 
    file attributes ${ssh_path}/$keyname -owner ${user} -group ${user} -permissions 0600
    # Is the key encrypted?
    if { [regexp -line {^Proc-Type:\s+\d,ENCRYPTED$} $private_key] } {
        # Decrypt the key on disk
        sh ssh-keygen -p -N "" -f ${ssh_path}/$keyname
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

proc muppet::ssh_user_authorize_key {user key} {
    if { [muppet::user_exists $user] } {
        set ssh_path "[muppet::user_home $user]/.ssh"
        if { ![file exists $ssh_path] } {
	    file mkdir $ssh_path
	    file attributes $ssh_path -owner $user -group $user -permissions 0700
        }
        if { ![file exists $ssh_path/authorized_keys] || ![file_contains_line $ssh_path/authorized_keys $key] } {
	    file_append ${ssh_path}/authorized_keys $key
	    file attributes $ssh_path/authorized_keys -owner $user -group $user -permissions 0644
        }
    } else {
        error "No such user $user"
    }
} 

proc muppet::ssh_user_config {method user host args} {
    #| sets ssh_config $host clause in $user's .ssh dir
    # eg. ssh_user_config set root muppet_repo HostName debian.qcode.co.uk User muppet IdentityFile ~/.ssh/id_muppet_rsa
    # will add the following to ~/.ssh/config in root's home dir.
    # Host muppet_repo
    # Hostname debian.qcode.co.uk
    # User muppet
    # IdentityFile ~/.ssh/id_muppet_rsa
    # Assumptions:
    #  - each host clause is named uniquely

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

    # {1,1}? required to specify non-greedy matching over the whole RE
    regexp -nocase "(?:(?:^|\\n)\\s*Host\\s+${host}\\s+.*(?:(?=\\n\\s*Host\\s)|$)){1,1}?" $config host_clause
    if { [info exists host_clause] } {

        set host_clause [string trim $host_clause]
    }
    switch $method {
        set {
            # Clause is being set. Replace $host_clause if exists.
            # Build host dict - host must always be first
            set host_dict [dict create host $host {*}[qc::lower $args]]
            set new_host_clause [muppet::ssh_user_config_host_dict2clause $host_dict]
            if { [info exists host_clause] } {
                set config [string map [subst -nobackslashes -nocommands {{$host_clause} {$new_host_clause}}] $config]
            } else {
                append config "$new_host_clause\n\n"
            }
        }
        update {
            # Clause is being updated. $host_clause will be changed and rewritten.
            set host_dict [qc::lower [string trim $host_clause]]
            # Update host_dict
            foreach {name value} [qc::lower $args] {
                dict set host_dict $name $value
            }
            # get new host clause from updated dict
            set new_host_clause [muppet::ssh_user_config_host_dict2clause $host_dict]
            # Substitute old host_clause for new
            set config [string map [subst -nobackslashes -nocommands {{$host_clause} {$new_host_clause}}] $config]
        }
        delete {
            # Clause is being deleted. $host_clause will be removed.
            set config [string map [subst -nocommands -nobackslashes {{$host_clause} {}}] $config]
        }
        default {
            error "Unknown method. Must be one of set, update or delete."
        }
    }

    return $config
}

proc muppet::ssh_user_config_host_dict2clause { host_dict} {
    set lines {}
    dict for {key value} $host_dict {
        lappend lines "$key $value"
    }
    return [join $lines \n]
}

proc muppet::ssh_private_repo { repo repo_host } {
    #| Set up access to a ssh private repo for the root user.
    #
    # eg. ssh_repo_access private my_repo.domain.co.uk
    # Will look for an encrypted private key at a remote location and save it as /root/.ssh/id_private_rsa
    # The encrypted key will be decypted on disk requiring the encryption key to be entered by the user.
    # An ssh config will be added as follows to use the saved private key to access this repo:
    #
    # Host private_repo
    # HostName my_repo.domain.co.uk
    # User private
    # IdentityFile ~/.ssh/id_private_rsa
    #
    # and a sources.list entry will be added for a repo in /home/private using the "private" user to alias private_repo.
    # This proc assumes the associated public key is already installed on the repo_host for the correct user.

    puts "Key remote location:"
    set key_location [gets_with_timeout 100000 ""]
    set key [http_get http://${key_location}/id_${repo}_rsa]
    puts "..found id_${repo}_rsa"
    ssh_user_private_key root $key "id_${repo}_rsa"
    
    muppet::ssh_user_config set root ${repo}_repo HostName $repo_host User $repo IdentityFile ~/.ssh/id_${repo}_rsa
    
    # Add to sources.list
    set repo_source "deb ssh://${repo}_repo:/home/${repo}/ squeeze main"
    if { ![file_contains_line /etc/apt/sources.list $repo_source] } {
        file_append /etc/apt/sources.list $repo_source
    }
}
