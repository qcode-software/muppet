package provide muppet 1.2.0
package require fileutil
package require qcode
namespace eval muppet {
    namespace export *
} 

proc muppet::ssl_key {} {
    install openssl
    return [::exec -ignorestderr -- openssl genrsa 2048]
}

proc muppet::ssl_cert {key} {
    install openssl
    package require fileutil
    set key_filename [file_temp $key]
    set cert_filename [fileutil::tempfile]
    if { [qc::param_exists ssl_default_cnf] } {
        set config_filename [file_temp [qc::param_get ssl_default_cnf]]
        sh openssl req -config $config_filename -new -x509 -key $key_filename -days 365 -out $cert_filename
        file delete $config_filename
    } else {
        sh openssl req -new -x509 -key $key_filename -days 365 -out $cert_filename
    }
    set cert [cat $cert_filename]
    file delete $key_filename
    file delete $cert_filename
    return $cert
}
