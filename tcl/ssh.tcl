package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {}

proc muppet::ssh_user_private_key {user private_key} {
    if { $user eq "root" } {
	set ssh_path /root/.ssh 
    } else { 
	set ssh_path /home/$user/.ssh  
    } 
    if { ![file exists $ssh_path] } {
	file mkdir $ssh_path
	file attributes $ssh_path -owner $user -group $user -permissions 0700
    }
    file_write $ssh_path/id_rsa $private_key 0600 
    file attributes $ssh_path/id_rsa -owner ${user} -group ${user} -permissions 0600
}

proc muppet::ssh_user_public_key {user private_key} {
    if { $user eq "root" } {
	set ssh_path /root/.ssh 
    } else { 
	set ssh_path /home/$user/.ssh  
    } 
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
    set key_path "/root/.ssh/id_${repo}_rsa"
    file_write $key_path $key 0600

    # Decrypt the key on disk for passwordless operation
    # TODO We could use keychain to do this in memory only
    exec ssh-keygen -p -f $key_path

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
