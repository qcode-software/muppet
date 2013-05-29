package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {
    namespace export *
} 

proc muppet::prompt_user {args} {
    #| Prompt user for input
    args $args -password -passwd -boolean -bool -- message
    
    if { [info exists password] || [info exists passwd]} {
        # Prompt user for password (do not echo password to stdout)
        exec stty -echo
        set input [prompt_user $message]
        exec stty echo
    } elseif { [info exists boolean] || [info exists bool] } {
        #| Prompt for boolean input from user
        append message " (yes/no)"
        set input [prompt_user $message]
        while { ![true $input] && ![false $input] } {
            set input [prompt_user $message]
        }
        set input [cast_bool $input true false]
    } else {
        # Default: Prompt user for input
        puts $message
        gets stdin input
    }
    return $input    
}
