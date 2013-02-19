package provide muppet 1.0
package require fileutil
package require qcode 1.8
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
    set config_filename [file_temp [qc::param ssl_default_cnf]]
    set key_filename [file_temp $key]
    set cert_filename [fileutil::tempfile]
    sh openssl req -config $config_filename -new -x509 -key $key_filename -days 365 -out $cert_filename
    set cert [cat $cert_filename]
    file delete $config_filename
    file delete $key_filename
    file delete $cert_filename
    return $cert
}
