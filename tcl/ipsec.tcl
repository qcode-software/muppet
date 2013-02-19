package provide muppet 1.0
namespace eval muppet {}

# TODO Deprecate?

proc muppet::etc_ipsec-tools.conf {myip peerip} {
    return [subst -nocommands { flush;
 spdflush;

spdadd $myip $peerip any -P out ipsec
    esp/transport//require
    ah/transport//require;
                      
spdadd $peerip $myip any -P in ipsec
    esp/transport//require
    ah/transport//require;
}]
}

proc muppet::etc_racoon_racoon.conf { myip myhostname peerip peerhostname } {
    return [subst -nocommands {path certificate "/etc/racoon/certs";

sainfo anonymous

\{
        pfs_group 2;
        lifetime time 1 hour ;
        encryption_algorithm 3des, blowfish 448, rijndael ;
        authentication_algorithm hmac_sha1, hmac_md5 ;
        compression_algorithm deflate ;
\}
        
remote $peerip
\{
         exchange_mode aggressive, main;
         my_identifier asn1dn;
         peers_identifier asn1dn;

         certificate_type x509 "${myhostname}.public" "${myhostname}.private";

         peers_certfile x509 "${peerhostname}.public";

         proposal \{
                encryption_algorithm 3des;
                hash_algorithm sha1;
                authentication_method rsasig;
                dh_group 2;
        \}
\}

}]
}

proc muppet::ipsec_install {hostname1 ip1 hostname2 ip2} {

    #TODO how to determine is ipsec is already correctly functioning between given hosts meaning nothing is to be done.
    # is checking for running racoon and setkey services enough?
    #TODO will likely, in the future, need to take into account the case where 1 host speaks to more than 1 peer 
    # eg. having more than one "remote" stanza in the config file
   
    # fictional proc to install packages on another machine
    install_remote { $hostname1 $hostname2 } {ipsec-tools racoon openssl}

    # X509 certs
    file_write root@${hostname1}:/tmp/qcode.cnf [qc::param ssl_default_cnf] 0644
    file_write root@${hostname2}:/tmp/qcode.cnf [qc::param ssl_default_cnf] 0644

    # fictional proc to exec a command on another host # TODO could be done with file_write as above perhaps
    exec_remote $hostname1 "mkdir /etc/racoon/certs"
    exec_remote $hostname2 "mkdir /etc/racoon/certs"

    # TODO a local CA could in theory create all these certs locally and simply use file_write to transfer to each host?
    if { ![file exists root@${hostname1}:/etc/racoon/certs/${hostname1}.private || ![file exists /etc/racoon/certs/${hostname1}.public] } {
        exec_remote $hostname1 "openssl req -config /tmp/qcode.cnf -days 3650 -new -nodes -newkey rsa:1024 -sha1 -keyform PEM -keyout /etc/racoon/certs/${hostname1}.private -outform PEM -out /etc/racoon/certs/${hostname1}_req.pem"
        exec_remote $hostname1 "openssl x509 -req -days 3650 -in /etc/racoon/certs/${hostname1}_req.pem -signkey /etc/racoon/certs/${hostname1}.private -out /etc/racoon/certs/${hostname1}.public"
        file_write root@$hostname2:/etc/racoon/certs/${hostname1}.public [cat root@${hostname1}:/etc/racoon/certs/${hostname1}.public] 0600
    }

    if { ![file exists root@${hostname2}:/etc/racoon/certs/${hostname2}.private ||  ![file exists /etc/racoon/certs/${hostname2}.public] } {
        exec_remote $hostname2 "openssl req -config /tmp/qcode.cnf -days 3650 -new -nodes -newkey rsa:1024 -sha1 -keyform PEM -keyout /etc/racoon/certs/${hostname2}.private -outform PEM -out /etc/racoon/certs/${hostname2}_req.pem"
        exec_remote $hostname2 "openssl x509 -req -days 3650 -in /etc/racoon/certs/${hostname2}_req.pem -signkey /etc/racoon/certs/${hostname2}.private -out /etc/racoon/certs/${hostname2}.public"
        file_write root@$hostname1:/etc/racoon/certs/${hostname2}.public [cat root@${hostname2}:/etc/racoon/certs/${hostname2}.public] 0600
    }

    # /etc/ipsec-tools.conf
    file_write root@${hostname1}:/etc/ipsec-tools.conf [etc_ipsec-tools.conf $ip1 $ip2] 0644
    file_write root@${hostname2}:/etc/ipsec-tools.conf [etc_ipsec-tools.conf $ip2 $ip1] 0644

    # /etc/racoon/racoon.conf
    file_write root@${hostname1}:/etc/racoon/racoon.conf [etc_racoon_racoon.conf $hostname1 $ip1 $hostname2 $ip2] 0644
    file_write root@${hostname2}:/etc/racoon/racoon.conf [etc_racoon_racoon.conf $hostname2 $ip2 $hostname1 $ip1] 0644
    
    service_remote $hostname1 racoon stop
    service_remote $hostname2 racoon stop

    service_remote $hostname1 setkey stop
    service_remote $hostname2 setkey stop

    service_remote $hostname1 setkey start
    service_remote $hostname2 setkey start

    service_remote $hostname1 racoon start
    service_remote $hostname2 racoon start
}
