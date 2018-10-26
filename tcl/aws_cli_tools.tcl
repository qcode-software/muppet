package require qcode 8
namespace eval muppet {
    namespace export *
} 

proc muppet::aws { args } {
    #| Execute a AWS command in the correct environment
    #
    # Old CLI example:
    # muppet aws ec2-describe-instances
    #
    # New CLI example
    # muppet aws elb describe-load-balancers
    #
    # Required variables are:
    # ::env(AWS_ACCESS_KEY_ID)
    # ::env(AWS_SECRET_ACCESS_KEY)
    # ::env(AWS_DEFAULT_REGION)
    #
    # Either set environment vars directly, or call qc::aws_credentials_set & qc::aws_region_set 
    # in the muppet rc script ~/.muppet/muppet.tcl
    # eg.
    # qc::aws_credentials_set [qc::param_get aws my_access_key] [qc::param_get my_secret_key]
    # qc::aws_region_set eu-west-1
    #
    qc::args $args -json -- args
    if { [string match "ec2-*" $args] } {
        # Old EC2 CLI 
        #| Sets required AWS environment variables for these tools

        # Update credentials environment - old ec2 tools use different naming
        set ::env(AWS_ACCESS_KEY) $::env(AWS_ACCESS_KEY_ID) 
        set ::env(AWS_SECRET_KEY) $::env(AWS_SECRET_ACCESS_KEY) 

        # Update environment
        set ::env(EC2_HOME) /usr/local/bin/ec2-api-tools
        set ::env(PATH) ${::env(PATH)}:${::env(EC2_HOME)}/bin
        set ::env(JAVA_HOME) /usr
        set ::env(EC2_URL) https://ec2.${::env(AWS_DEFAULT_REGION)}.amazonaws.com

        # Execute command
        return [exec {*}$args]

    } else {
        # New AWS unified CLI command
        if { [info exists json] } {
            set ::env(AWS_DEFAULT_OUTPUT) "json"
        } else {
            set ::env(AWS_DEFAULT_OUTPUT) "text"
        }
        return [exec aws {*}$args]
    }
}

proc muppet::aws_cli_tools_install {} {
    #| Install the Amazon Web Services unified command line interface tool.
    install python unzip
    cd /tmp
    file_download https://s3.amazonaws.com/aws-cli/awscli-bundle.zip
    set unzip [qc::which unzip]
    sh $unzip /tmp/awscli-bundle.zip
    sh /tmp/awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    file delete -force /tmp/awscli-bundle
    file delete /tmp/awscli-bundle.zip
}

proc muppet::aws_describe_instances {args} {
    #| Return ldict of info about each instance matching crtieria.
    # "aws_instances -state running -security_group MLA_DEV_SG"
    # This will match instances in state running AND with security_group MLA_DEV_SG
    args $args -state "" -states {} -security_group ""  -security_groups {}

    # Filters
    set filters {}
    if { $state ne "" } {
        lappend states $state
    }
    if { [llength $states] > 0 } {
        lappend filters Name=instance-state-name,Values=[join $states ,]
    }
    if { $security_group ne "" } {
        lappend security_groups $security_group
    }
    if { [llength $security_groups] > 0 } {
        lappend filters Name=instance.group-name,Values=[join $security_groups ,]
    }
    
    set args {}
    if { [llength $filters] > 0 } {
        lappend args --filters {*}$filters
    }
    set json [muppet::aws ec2 describe-instances --output json {*}$args]
    set result [::json::json2dict $json]
    
    set instances {}
    foreach reservation [dict get $result Reservations] {
        foreach instance [dict get $reservation Instances] {
            lappend instances $instance
        }
    }
    return $instances
}
