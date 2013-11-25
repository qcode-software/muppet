package provide muppet 1.0
package require qcode
namespace eval muppet {
    namespace export *
} 

proc muppet::aws_cli_tools_install {} {
    #| Install the Amazon Wed Services unified command line interface tool.
    install python
    cd /tmp
    file_download https://s3.amazonaws.com/aws-cli/awscli-bundle.zip
    set unzip [exec which unzip]
    sh $unzip /tmp/awscli-bundle.zip
    sh /tmp/awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    file delete -force /tmp/awscli-bundle
    file delete /tmp/awscli-bundle.zip
    muppet::aws_cli_config_update
}

proc muppet::aws_cli_config_update {} {
    #| Sets aws credentials referred to by the aws_default param
    # eg.
    # qc::param_set aws_default aws_testing
    # qc::param_set aws_testing [list access_key "XXXXXXXXXXXXXX" secret_access_key "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"]
    # qc::param_set aws_qcode [list access_key "XXXXXXXXXXXXXX" secret_access_key "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"]
    
    set access_key [dict get [qc::param_get [qc::param_get aws_default]] access_key]
    set secret_access_key [dict get [qc::param_get [qc::param_get aws_default]] secret_access_key]

    set config "
\[default\]
region=eu-west-1
output=text
aws_access_key_id=$access_key
aws_secret_access_key=$secret_access_key
"

    file mkdir  ~/.aws
    file_write ~/.aws/config $config
    file attributes ~/.aws/config -owner root -group root -permissions 0600

}
