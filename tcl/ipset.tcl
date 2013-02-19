package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {
    namespace export *
}

proc muppet::ipset_exists { ipset_name } {
    return [regexp -- "Name: $ipset_name" [exec /usr/sbin/ipset --list]]
}

proc muppet::ipset_update { ipset_name type args } {
    if { ![ipset_exists $ipset_name] } {
	sh ipset --create $ipset_name $type
    }
    # create a temp ipset
    set ipset_tmp ${ipset_name}_[qc::cast_epoch now]
    sh ipset --create $ipset_tmp $type
    foreach item [qc::lunique $args] {
        sh /usr/sbin/ipset --add $ipset_tmp $item
    }
    # swap & delete
    sh /usr/sbin/ipset --swap $ipset_tmp $ipset_name
    sh /usr/sbin/ipset --destroy $ipset_tmp
}

