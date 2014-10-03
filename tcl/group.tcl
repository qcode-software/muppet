package provide muppet 1.2.7
package require qcode

namespace eval muppet {
    namespace export *
} 

proc muppet::group_exists { group } {
   if { [catch {::exec grep "^$group:" /etc/group}] } {
       return false
   } {
       return true
   }
}

proc muppet::group_add { group } {
    # If group doesn't exist, add it.
    if { ![group_exists $group] } {
        puts "adding group $group"
        sh groupadd $group
    } 
}
