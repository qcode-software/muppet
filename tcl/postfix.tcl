package provide muppet 1.1.0
package require qcode
namespace eval muppet {
    namespace export *
}

proc muppet::postfix_local_only_install {} {
    #| Install postfix using the Local Only option
    package_option postfix postfix/root_address string ""
    package_option postfix postfix/rfc1035_violation boolean false
    package_option postfix postfix/mydomain_warning boolean ""
    package_option postfix postfix/mynetworks string {127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128}
    package_option postfix postfix/mailname string "[my fqdn]"
    package_option postfix postfix/tlsmgr_upgrade_warning boolean ""
    package_option postfix postfix/recipient_delim string "+"
    package_option postfix postfix/main_mailer_type select "Local only"
    package_option postfix postfix/destinations string ""
    package_option postfix postfix/retry_upgrade_warning boolean ""
    package_option postfix postfix/kernel_version_warning boolean ""
    package_option postfix postfix/sqlite_warning boolean ""
    package_option postfix postfix/mailbox_limit string 0
    package_option postfix postfix/relayhost string ""
    package_option postfix postfix/procmail boolean true
    package_option postfix postfix/protocols select all
    package_option postfix postfix/chattr boolean false

    install postfix 
}

