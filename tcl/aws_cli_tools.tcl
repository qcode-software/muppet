package provide muppet 1.1.0
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
    if { [string match "ec2-*" $args] } {
        # Old EC2 CLI command
        muppet::aws_ec2_tools_env_set
        return [exec {*}$args]
    } else {
        # New AWS unified CLI command
        muppet:::aws_cli_tools_env_set 
        return [exec aws {*}$args]
    }
}

proc muppet::aws_cli_tools_install {} {
    #| Install the Amazon Wed Services unified command line interface tool.
    install python
    cd /tmp
    file_download https://s3.amazonaws.com/aws-cli/awscli-bundle.zip
    set unzip [qc::which unzip]
    sh $unzip /tmp/awscli-bundle.zip
    sh /tmp/awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    file delete -force /tmp/awscli-bundle
    file delete /tmp/awscli-bundle.zip
}

proc muppet:::aws_cli_tools_env_set {} {
    #| Sets aws credentials referred to by the aws_default param
   
    set account [qc::param_get aws default]

    set ::env(AWS_DEFAULT_REGION) [qc::param_get aws $account region]
    set ::env(AWS_ACCESS_KEY_ID) [qc::param_get aws $account access_key]
    set ::env(AWS_SECRET_ACCESS_KEY) [qc::param_get aws $account secret_access_key]
    set ::env(AWS_DEFAULT_OUTPUT) "text"
}

