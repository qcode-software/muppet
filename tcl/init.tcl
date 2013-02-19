package provide muppet 1.0
package require qcode 1.8

# Load configuration file
if { [file exists "/etc/muppet.tcl"] } {
    source /etc/muppet.tcl
}
