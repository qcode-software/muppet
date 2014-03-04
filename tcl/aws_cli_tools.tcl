package provide muppet 1.2.4
package require qcode
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
        set ::env(AWS_DEFAULT_OUTPUT) "text"
        return [exec aws {*}$args]
    }
}

proc muppet::aws_cli_tools_install {} {
    #| Install the Amazon Web Services unified command line interface tool.
    install python
    cd /tmp
    file_download https://s3.amazonaws.com/aws-cli/awscli-bundle.zip
    set unzip [qc::which unzip]
    sh $unzip /tmp/awscli-bundle.zip
    sh /tmp/awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    file delete -force /tmp/awscli-bundle
    file delete /tmp/awscli-bundle.zip
}
