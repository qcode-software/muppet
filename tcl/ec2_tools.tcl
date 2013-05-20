package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {
    namespace export *
} 

proc muppet::ec2_tools_install {} {
    #| Installs AWS EC2 tools so they are accessable by the root user on the local machine
    install gnupg unzip openjdk-6-jre
    muppet::rng_tools_install
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

    # gpg keys
    set gpg [exec which gpg]
    # Have we generated a key before?
    qc::try {
        set gpg_out [exec $gpg --fingerprint "(ec2_gpg_key) <[qc::param email_contact]>"]
        # Yes, take the first matching key
        regexp -linestop -lineanchor {^pub\s+\S+/(\S+)\s[\d]{4}-[\d]{2}-[\d]{2}$} $gpg_out -> my_key
    } {
        # Or no, no key has been generated for ec2 - do it now
        muppet::file_write /tmp/gpg_input.tmp "[muppet::ec2_gpg_key_gen_input]"
        
        muppet::service rng-tools start
        set gpg_out [exec $gpg --batch --gen-key /tmp/gpg_input.tmp 2>@1]
        muppet::service rng-tools stop

        regexp -linestop -lineanchor -all {^gpg:\skey\s([^[:space:]]+)\s.+$} $gpg_out -> my_key
        file delete /tmp/gpg_input.tmp
    } 
    
    # ec2 packages public key
    muppet::file_write /tmp/ec2-packages-public.key "[muppet::ec2_packages_public_key]"
    set gpg_out [exec -ignorestderr -- $gpg --import /tmp/ec2-packages-public.key 2>@1]
    file delete /tmp/ec2-packages-public.key
    regexp -linestop -lineanchor -all {^gpg:\skey\s([^[:space:]]+):.+$} $gpg_out -> ec2_key
   
    # Get the EC2 key fingerprint
    set gpg_fingerprint [exec -ignorestderr -- $gpg --fingerprint $ec2_key 2>@1]
    regexp -linestop -lineanchor -all {Key\sfingerprint\s=\s(.+)$} $gpg_fingerprint -> fingerprint
    # Append the trust level to the fingerprint 4=Fully trust
    set fingerprint "[string map {" " ""} $fingerprint]:4:\n"
    muppet::file_write /tmp/ec2-fingerprint.txt $fingerprint
    sh $gpg --import-ownertrust < /tmp/ec2-fingerprint.txt
    file delete /tmp/ec2-fingerprint.txt

    # sign the EC2 key using the local key generated above
    sh $gpg --yes --batch --local-user $my_key --sign-key $ec2_key

    # EC2 credentials
    sh mkdir -p /root/.ec2
    muppet::file_write /root/.ec2/ec2-cacert.pem [qc::param ec2_cert]

    # Make the tools accessable by the root user
    if { ![muppet::file_contains_line /root/.profile "export EC2_CERT=/root/.ec2/ec2-cacert.pem"] } {
        puts "Updating /root/.profile..."
        muppet::file_append /root/.profile [muppet::ec2_env]
    }
    # Also dynamically set the ENV variables
    set env(EC2_HOME) "/usr/local/bin/ec2-api-tools"
    set env(PATH) {$PATH:$EC2_HOME/bin}
    set env(JAVA_HOME) "/usr"
    set env(EC2_PRIVATE_KEY) "/root/.ec2/ec2-private-key.pem"
    set env(EC2_CERT) "/root/.ec2/ec2-cacert.pem"
    set env(EC2_URL) "https://ec2.eu-west-1.amazonaws.com"

    # paste the private key into this file from keepass to finish up
    puts "Install your AWS private key in /root/.ec2/ec2-private-key.pem"

}

proc muppet::ec2_delete_snapshots_older_than { days } {
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

proc muppet::ec2_snapshot_self {} {
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

proc muppet::ec2_endpoint_change {} {
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
        regexp -linestop -lineanchor {^(export\sEC2_URL=\S+)$} [muppet::cat /root/.profile] -> ec2_url
        
        # Change it to the new value
        muppet::file_write /root/.profile [muppet::file_minus_line /root/.profile $ec2_url]
        muppet::file_append /root/.profile "export EC2_URL=https://$endpoints($input)"
        puts "Source /root/.profile to update environment"
    }
}

proc muppet::ec2_env {} {
    # TODO endpoint defaults to Ireland for now - will need a way to change this easily
    return {
export EC2_HOME=/usr/local/bin/ec2-api-tools
export PATH=$PATH:$EC2_HOME/bin
export JAVA_HOME=/usr
export EC2_PRIVATE_KEY=/root/.ec2/ec2-private-key.pem
export EC2_CERT=/root/.ec2/ec2-cacert.pem
export EC2_URL=https://ec2.eu-west-1.amazonaws.com
    }
}

proc muppet::ec2_packages_public_key {} {
    # This is the key published here:
    # https://aws.amazon.com/security/ec2-pkgs-public-key/
    return {-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG/MacGPG2 v2.0.14 (Darwin)

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
oJIMz+Rn
=9/Ou

-----END PGP PUBLIC KEY BLOCK-----
}
}


proc muppet::ec2_gpg_key_gen_input {} {
    return [subst {Key-Type: DSA
Key-Length: 1024
Subkey-Type: ELG-E
Subkey-Length: 1024
Name-Real: [qc::my hostname]
Name-Comment: ec2_gpg_key
Name-Email: [qc::param email_contact]
Expire-Date: 0
%commit
}]
}

proc muppet::rng_tools_install {} {
    #| entropy gethering in the cloud seems to take an awful long time.
    # This entropy gathering daemon will make the certificate generating
    # process take seconds rather than minutes
    install rng-tools
    muppet::file_write /etc/default/rng-tools [muppet::etc_default_rng-tools]
}

proc muppet::etc_default_rng-tools {} {
    return {# Configuration for the rng-tools initscript
# $Id: rng-tools.default,v 1.1.2.5 2008-06-10 19:51:37 hmh Exp $

# This is a POSIX shell fragment

# Set to the input source for random data, leave undefined
# for the initscript to attempt auto-detection.  Set to /dev/null
# for the viapadlock driver.
HRNGDEVICE=/dev/urandom

# Additional options to send to rngd. See the rngd(8) manpage for
# more information.  Do not specify -r/--rng-device here, use
# HRNGDEVICE for that instead.
#RNGDOPTIONS="--hrng=intelfwh --fill-watermark=90% --feed-interval=1"
#RNGDOPTIONS="--hrng=viakernel --fill-watermark=90% --feed-interval=1"
#RNGDOPTIONS="--hrng=viapadlock --fill-watermark=90% --feed-interval=1"
}
}
