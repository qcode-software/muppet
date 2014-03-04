package provide muppet 1.2.4
package require qcode
namespace eval muppet {
    namespace export *
}

proc muppet::ntp_generic_client_conf {} {
    #| Generic NTP config which should be viable within a VM (tinker panic 0)
    return {tinker panic 0
driftfile /var/lib/ntp/ntp.drift

# Enable this if you want statistics to be logged.
#statsdir /var/log/ntpstats/

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

# You do need to talk to an NTP server or two (or three).
#server ntp.your-provider.example

server 0.uk.pool.ntp.org iburst
server 1.uk.pool.ntp.org iburst
server 2.uk.pool.ntp.org iburst
server 3.uk.pool.ntp.org iburst

# By default, exchange time with everybody, but don't allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod notrap nomodify nopeer noquery

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1

    }
}

proc muppet::ntp_generic_client_install {} {
    # Install and start NTP client
    
    install ntp

    # Write config files
    file_write "/etc/ntp.conf" [muppet::ntp_generic_client_conf] 0644

    # Restart daemon
    service ntp restart
}
