package provide muppet 1.0
package require qcode
namespace eval muppet {
    namespace export *
} 

proc muppet::aws_ec2_tools_install {} {
    #| Installs AWS EC2 tools so they are accessable by the root user on the local machine
    install gnupg unzip openjdk-6-jre
    set unzip [exec which unzip]

    # Download tools archive to /usr/local/bin
    cd /usr/local/bin
    file_download http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
    # sh cp /usr/local/bin/ec2-api-tools.zip.1 /usr/local/bin/ec2-api-tools.zip
    
    # work out what the tools' directory will be called
    set ec2_zip_contents [exec $unzip -l ec2-api-tools.zip]
    regexp -linestop -lineanchor {^\s+\d+\s\s[\d]{4}-[\d]{2}-[\d]{2}\s[\d]{2}:[\d]{2}\s+(\S+)/\S*$} $ec2_zip_contents -> ec2_tools_dir_name

    # Do the unzip
    sh $unzip -o -u ec2-api-tools.zip
    file delete ec2-api-tools.zip
    muppet::file_link "/usr/local/bin/ec2-api-tools" "/usr/local/bin/$ec2_tools_dir_name"

}

proc muppet::aws_delete_snapshots_older_than { days } {
    #| Delete all snapshots for this instance which are older than $days days
    muppet::aws_ec2_tools_env_set
    # List all volumes for this instance (often only 1)
    set volumes [exec ec2-describe-volumes --filter attachment.instance-id=[qc::my instance_id]]
    foreach {match volume_id filesystem} [regexp -linestop -lineanchor -all -inline "^ATTACHMENT\\s+(\\S+)\\s+\\S+\\s+(\\S+)\\s+.+\$" $volumes] { 
        # For volumes associated with this instance, iterate through all corresponding complete snapshots
        set snapshots [exec ec2-describe-snapshots --filter volume-id=$volume_id]
        foreach {match snapshot_id timestamp} [regexp -linestop -lineanchor -all -inline "^SNAPSHOT\\s+(\\S+)\\s+$volume_id\\s+completed\\s+(\\S+)\\s+100%.+\$" $snapshots] { 
            if {[qc::date_days [qc::cast_date $timestamp] [qc::cast_date now]] > $days } {
                exec ec2-delete-snapshot $snapshot_id
            }
        }
    }
}

proc muppet::aws_snapshot_self {} {
    #| Creates snapshots of all volumes attached to the local EC2 instance
    # TODO uses sync rather than xfs_freeze for now
    muppet::aws_ec2_tools_env_set
    set volumes [exec ec2-describe-volumes]
    set instance_id [qc::my instance_id]
    foreach {match volume_id filesystem} [regexp -linestop -lineanchor -all -inline "^ATTACHMENT\\s+(\\S+)\\s+$instance_id\\s+(\\S+)\\s+.+\$" $volumes] { 
        exec sync
        exec sync
        exec ec2-create-snapshot $volume_id -d "[qc::my hostname] $filesystem on $volume_id"
    }
}

proc muppet::aws_ec2_tools_env_set { } {
    #| Sets up aws credentials for old ec2 cli tools
    # qc::param_set aws default account1
    # qc::param_set aws account1 region "eu-west-1"
    # qc::param_set aws account1 access_key "xxxxxxxxxxxxxxxx"
    # qc::param_set aws account1 secret_access_key "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    #
    # qc::param_set aws account2 region "eu-west-1"
    # qc::param_set aws account2 access_key "xxxxxxxxxxxxxxxx"
    # qc::param_set aws account2 secret_access_key "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    #
    # qc::param_set aws account3 region "eu-west-1"
    # qc::param_set aws account3 access_key "xxxxxxxxxxxxxxxx"
    # qc::param_set aws account3 secret_access_key "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    #
    
    # AWS account to default to
    set account [qc::param_get aws default]

    # Update current environment
    set ::env(AWS_ACCESS_KEY) [qc::param_get aws $account access_key]
    set ::env(AWS_SECRET_KEY) [qc::param_get aws $account secret_access_key]
    set ::env(EC2_HOME) /usr/local/bin/ec2-api-tools
    set ::env(PATH) ${::env(PATH)}:${::env(EC2_HOME)}/bin
    set ::env(JAVA_HOME) /usr
    set ::env(EC2_URL) https://ec2.[qc::param_get aws $account region].amazonaws.com

}
 

