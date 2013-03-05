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
    #  - any global setting appear at the beginning of the file
    #  - doesn't support regular expression Host matching yet

    set config_path "[user_home $user]/.ssh"
    set config_file "$config_path/config"
    if { ![file exists $config_path] } {
        sh mkdir $config_path
    }
    if { ![file exists $config_file } {
        # config is new
        sh touch $config_file
        set config ""
    } else {
        # config exists
        set config [muppet::cat $config_file]
        # get any global settings
        # regexp -nocase {.*?(?:(?=\nHost )|(?=$))} $config global_settings
        regexp -nocase "\\nHost\\s+?${host}\\s*?\\n.*?(?:(?=\\nHost )|(?=$))" $config host_clause
    }

    switch $method {
        set {
            # Clause is being set. Delete $host_clause if exists and recreate.
            set host_clause_new "
host $host"
            foreach {name value} $args {
                append host_clause_new "
$name $value
"
            }
            if { ![regsub $host_clause $config $host_clause_new config] } {
                append config $host_clause_new
            }

        }
        update {
            # Clause is being updated. $host_clause will be changed and rewritten.
        }
        delete {
            # Clause is being deleted. $host_clause will be removed.
        }
        default {
            error "Unknown method. Must be one of set, update or delete."
        }
    }
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

    set ssh_config "Host ${repo}_repo
HostName $repo_host
User $repo
IdentityFile ~/.ssh/id_${repo}_rsa

"
    set ssh_config_file "/root/.ssh/config"
    if { ![file exists $ssh_config_file] } {
        file_write $ssh_config_file $ssh_config
    } else {
        if { ![file_contains_line $ssh_config_file "IdentityFile ~/.ssh/id_${repo}_rsa" ] } {
            # File exists, prepend entry to config
            set file_contents [muppet::cat $ssh_config_file]
            append ssh_config $file_contents
            file_write $ssh_config_file $ssh_config
        }
    }
    
    # Add to sources.list
    set repo_source "deb ssh://${repo}_repo:/home/${repo}/ squeeze main"
    if { ![file_contains_line /etc/apt/sources.list $repo_source] } {
        file_append /etc/apt/sources.list $repo_source
    }
}
