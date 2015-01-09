package require qcode 6

# Load configuration file
if { [info exists env(HOME)] && [file exists $env(HOME)/.muppet/muppet.tcl] } {
    source $env(HOME)/.muppet/muppet.tcl
}
if { [file exists "/etc/muppet.tcl"] } {
    source /etc/muppet.tcl
}
