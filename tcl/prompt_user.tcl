package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {
    namespace export *
} 

proc muppet::prompt_user {message} {
    #| Prompt user for input
    puts $message
    return [gets stdin]
}

proc muppet::prompt_user_password {message {global_variable ""}} {
    #| Prompt user for password (do not echo password to stdout)
    puts $message
    exec stty -echo
    set password [gets stdin]
    exec stty echo
    return $password
}

proc muppet::prompt_user_bool {message} {
    #| Prompt for boolean input from user
    append message " (yes/no)"
    set input [prompt_user $message]
    while { ![true $input] && ![false $input] } {
	set input [prompt_user $message]
    }
    return [cast_bool $input true false]
}
