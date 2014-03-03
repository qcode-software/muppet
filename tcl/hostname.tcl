package provide muppet 1.2.3
package require qcode
namespace eval muppet {
    namespace export *
}

proc muppet::hostname_update { hostname domain } {
    #| update /etc/hosts and /etc/hostname so that hostname and hostname -f return the
    # correct values (required for [my fqdn] etc.)

    # /etc/hosts
    set hosts {}
    lappend hosts "127.0.0.1	localhost localhost.localdomain"
    lappend hosts "127.0.1.1	${hostname}.${domain} $hostname"
    lappend hosts ""
    file_write /etc/hosts [join $hosts \n]
    # /etc/hostname
    file_write /etc/hostname "$hostname\n"
    # run hostname command to update hostname for this session
    sh hostname $hostname

}
