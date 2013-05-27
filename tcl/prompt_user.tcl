package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {
    namespace export *
} 

proc muppet::prompt_user {message} {
    #| Prompt for user input
    puts $message
    return [gets stdin]
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

proc muppet::prompt_user_encrypt {message plaintext} {
    #| Prompt User for key to encrypt ciphertext
    set key [prompt_user $message]
    return [encrypt_bf_tcl $key $plaintext]
}

proc muppet::prompt_user_decrypt {message ciphertext} {
    #| Prompt User for key to decrypt ciphertext
    set key [prompt_user $message]
    return [decrypt_bf_tcl $key $ciphertext]
}

