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
    if { $user eq "root" } {
	set ssh_path /root/.ssh 
    } else { 
	set ssh_path /home/$user/.ssh  
    } 
    if { ![file exists $ssh_path] } {
	file mkdir $ssh_path
	file attributes $ssh_path -owner $user -group $user -permissions 0700
    }
    if { ![file exists $ssh_path/authorized_keys] || ![file_contains_line $ssh_path/authorized_keys $key] } {
	file_append ${ssh_path}/authorized_keys $key
	file attributes $ssh_path/authorized_keys -owner $user -group $user -permissions 0644
    }
} 
