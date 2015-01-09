package require qcode 6
namespace eval muppet {
    namespace export *
} 

proc muppet::prompt_user {args} {
    #| Prompt user for input
    args $args -password -boolean -- message
    
    if { [info exists password] } {
        # Prompt user for password (do not echo password to stdout)
        exec stty -echo
        set input [prompt_user $message]
        exec stty echo
    } elseif { [info exists boolean] } {
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
