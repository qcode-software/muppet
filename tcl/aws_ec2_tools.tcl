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

    # Make the tools accessable by the root user
    # TODO finish regexp
    if { ![muppet::file_contains_line /root/.profile "export EC2_HOME=/usr/local/bin/ec2-api-tools"] } {
        puts "Updating /root/.profile..."
        muppet::file_append /root/.profile [muppet::aws_env]
    }
    # Also dynamically set the ENV variables
    set env(EC2_HOME) "/usr/local/bin/ec2-api-tools"
    set env(PATH) {$PATH:$EC2_HOME/bin}
    set env(JAVA_HOME) "/usr"
    set env(EC2_URL) "https://ec2.eu-west-1.amazonaws.com"

    # Set aws credentials
    muppet::aws_ec2_tools_credentials_set

}

proc muppet::aws_delete_snapshots_older_than { days } {
    #| Delete all snapshots for this instance which are older than $days days
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
    set volumes [exec ec2-describe-volumes]
    set instance_id [qc::my instance_id]
    foreach {match volume_id filesystem} [regexp -linestop -lineanchor -all -inline "^ATTACHMENT\\s+(\\S+)\\s+$instance_id\\s+(\\S+)\\s+.+\$" $volumes] { 
        exec sync
        exec sync
        exec ec2-create-snapshot $volume_id -d "[qc::my hostname] $filesystem on $volume_id"
    }
}

proc muppet::aws_endpoint_change {} {
    set regions [exec ec2-describe-regions]
    puts "Enter the number of the endpoint you want:"
    set count 1
    foreach region [split $regions \n] {
        lassign $region -> name endpoint
        set endpoints($count) $endpoint
        puts "$count. $endpoint \n"
        incr count
    }
    gets stdin input
    if { ![info exists endpoints($input)] } {
        puts "Invalid selection."
    } {
        puts "Endpoint $endpoints($input) selected"
        set env(EC2_URL) "https://$endpoints($input)"

        # Get current value of EC2_URL in .profile
        regexp -linestop -lineanchor {^(export\sEC2_URL=\S+)$} [muppet::cat /root/.profile] -> aws_url
        
        # Change it to the new value
        muppet::file_write /root/.profile [muppet::file_minus_line /root/.profile $aws_url]
        muppet::file_append /root/.profile "export EC2_URL=https://$endpoints($input)"
        puts "Source /root/.profile to update environment"
    }
}

proc muppet::aws_ec2_tools_credentials_set {} {
    #| Sets aws credentials referred to by the aws_default
    # eg.
    # variable aws_default aws_testing
    # variable aws_testing [list access_key "XXXXXXXXXXXXXX" secret_access_key "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"]
    # variable aws_qcode [list access_key "XXXXXXXXXXXXXX" secret_access_key "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"]
    
    set access_key [dict get [qc::param_get [qc::param_get aws_default]] access_key]
    set secret_access_key [dict get [qc::param_get [qc::param_get aws_default]] secret_access_key]

    # Start with no credentials
    if { [regexp -linestop -lineanchor {^(export\sAWS_ACCESS_KEY=\S+)$} [muppet::cat /root/.profile] -> aws_access_key_line] } {
        muppet::file_write /root/.profile [muppet::file_minus_line /root/.profile $aws_access_key_line]
    }
    if { [regexp -linestop -lineanchor {^(export\sAWS_SECRET_KEY=\S+)$} [muppet::cat /root/.profile] -> aws_secret_key_line] } {
        muppet::file_write /root/.profile [muppet::file_minus_line /root/.profile $aws_secret_key_line]
    }

    # Update .profile
    muppet::file_append /root/.profile "export AWS_ACCESS_KEY=$access_key
export AWS_SECRET_KEY=$secret_access_key"
    # Update current environment
    set env(AWS_ACCESS_KEY) $access_key
    set env(AWS_SECRET_KEY) $secret_access_key

    puts "Source /root/.profile to update aws environment to aws [qc::param_get aws_default]"
}

proc muppet::aws_env {} {
    # TODO endpoint defaults to Ireland for now - will need a way to change this easily
    return {
export EC2_HOME=/usr/local/bin/ec2-api-tools
export PATH=$PATH:$EC2_HOME/bin
export JAVA_HOME=/usr
export EC2_URL=https://ec2.eu-west-1.amazonaws.com
    }
}
