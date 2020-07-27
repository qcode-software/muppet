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
    # List all volumes for this instance (often only 1)
    set volumes [muppet::aws ec2-describe-volumes --filter attachment.instance-id=[qc::my instance_id]]
    foreach {match volume_id filesystem} [regexp -linestop -lineanchor -all -inline "^ATTACHMENT\\s+(\\S+)\\s+\\S+\\s+(\\S+)\\s+.+\$" $volumes] { 
        # For volumes associated with this instance, iterate through all corresponding complete snapshots
        set snapshots [muppet::aws ec2-describe-snapshots --filter volume-id=$volume_id]
        foreach {match snapshot_id timestamp} [regexp -linestop -lineanchor -all -inline "^SNAPSHOT\\s+(\\S+)\\s+$volume_id\\s+completed\\s+(\\S+)\\s+100%.+\$" $snapshots] { 
            if {[qc::date_days [qc::cast_date $timestamp] [qc::cast_date now]] > $days } {
                muppet::aws ec2-delete-snapshot $snapshot_id
            }
        }
    }
}

proc muppet::aws_snapshot_self {} {
    #| Creates snapshots of all volumes attached to the local EC2 instance
    # TODO uses sync rather than xfs_freeze for now
    set volumes [muppet::aws ec2-describe-volumes]
    set instance_id [qc::my instance_id]
    foreach {match volume_id filesystem} [regexp -linestop -lineanchor -all -inline "^ATTACHMENT\\s+(\\S+)\\s+$instance_id\\s+(\\S+)\\s+.+\$" $volumes] { 
        exec sync
        exec sync
        muppet::aws ec2-create-snapshot $volume_id -d "[qc::my hostname] $filesystem on $volume_id"
    }
}

