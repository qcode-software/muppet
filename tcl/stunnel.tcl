package provide muppet 1.0
package require qcode

namespace eval muppet {
    namespace export *
} 

proc muppet::stunnel_rekey {{key_filename UNDEF} {cert_filename UNDEF}} {
    
    default key_filename /etc/ssl/private/stunnel.key
    default cert_filename /etc/ssl/certs/stunnel.cert
    # Create self signed keys
    set key [ssl_key]
    file_write $key_filename $key 0400
    file_write $cert_filename [ssl_cert $key] 0400
}

proc muppet::stunnel_install {conf} {
    install stunnel4
     
    set key_filename /etc/ssl/private/stunnel.key
    set cert_filename /etc/ssl/certs/stunnel.cert
    if { ![file exists $key_filename] || ![file exists $cert_filename] } {
        stunnel_rekey $key_filename $cert_filename
    }

    file_regsub -line -- {^ENABLED=0$} /etc/default/stunnel4 "ENABLED=1" /etc/default/stunnel4   
    # Restart if config file has changed
    if { [file_write /etc/stunnel/stunnel.conf $conf 0644] } {
	service stunnel4 restart
    }
}
