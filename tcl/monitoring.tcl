package provide muppet 1.0
package require qcode
namespace eval muppet {}

proc muppet::disk_space_check { args } {
    #| Checks that specified filesystems have specified min percent free.
    # Eg. disk_space_check /home 20 / 20 /tmp 20 /var 20
   
    set df [exec /usr/bin/which df]
    set df_out [exec $df]

    foreach {filesystem percent_free_min} $args {
        regexp -linestop -lineanchor "^\\S+\\s+\\d+\\s+\\d+\\s+\\d+\\s+(\\d+)%\\s($filesystem)\$" $df_out -> percent_used
        if { $percent_free_min > [expr {100-$percent_used}] } {
            set text "[cast_timestamp now] ALERT: $filesystem is ${percent_used}% full."
            # Email alert
            qc::email_send \
                to [qc::param email_support] \
                from "muppet@[qc::my fqdn]" \
                subject "FILESYSTEM SPACE ALERT: [qc::my hostname] alert for $filesystem" \
                text $text
            # Output alert to stdout
            puts $text
        }
    }
}
