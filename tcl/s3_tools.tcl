package provide muppet 1.0
package require qcode 1.17
package require sha1
package require tdom
namespace eval muppet {
    namespace export *
} 

proc muppet::s3_url {bucket} {
    set base s3.amazonaws.com
    if { $bucket eq ""} {
        return $base
    } else {
        return ${bucket}.${base}
    }
}

proc muppet::s3_headers { verb path bucket } {
    set access_key [dict get [qc::param aws] access_key]
    #set access_key "AKIAIOSFODNN7EXAMPLE"
    set secret_access_key [dict get [qc::param aws] secret_access_key]
    #set secret_access_key "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    #set secret_access_key fakeaccesskey
    set date [qc::format_timestamp_http now]
    #set date "Tue, 27 Mar 2007 21:15:45 +0000"
   
    #TODO ignoring sub-resources for now
    if { $bucket ne "" } {
        #TODO url_path of / returns "" so need to change or make an exception
        if { $path eq "/" } {
            set canonicalized_resource "/$bucket/"
        } else {
            set canonicalized_resource "/$bucket[qc::url_path $path]"
        }
    } else {
        set canonicalized_resource "/"
    }
    puts "cr = $canonicalized_resource"

    # TODO ignoring canonicalized_amz_headers
    set canonicalized_amz_headers  ""

    set string_to_sign "$verb"
    # Content md5
    lappend string_to_sign ""  
    # Content type
    lappend string_to_sign ""  
    lappend string_to_sign $date
    lappend string_to_sign "${canonicalized_amz_headers}${canonicalized_resource}"
    set string_to_sign [join $string_to_sign \n]
    puts "sts = *${string_to_sign}*"
    puts "[string2hex ${string_to_sign}]"

    set signature [::base64::encode [::sha1::hmac -bin $secret_access_key $string_to_sign]]
    puts "sig = $signature"

    set authorization "AWS ${access_key}:$signature"
    puts "auth = $authorization"

    return [list Host [s3_url $bucket] Date $date Authorization $authorization]
}

proc muppet::s3_get { path {bucket ""} } {
    set headers [s3_headers GET $path $bucket] 
    return [qc::http_get -headers $headers [s3_url $bucket]]
}

proc string2hex s {
    binary scan $s H* hex
    regsub -all (..) $hex { \1}
 }

proc muppet::s3 { args } {
    switch [lindex $args 0] {
        ls {
	    set xmlDoc [s3_get /]
            set doc [dom parse $xmlDoc]
            set root [$doc documentElement]
            $doc selectNodesNamespaces "ns [$root getAttribute xmlns]"
            set buckets {}
            foreach bucket [$root selectNodes {/ns:ListAllMyBucketsResult/ns:Buckets/ns:Bucket}] {
                lappend buckets [[$bucket getElementsByTagName Name] asText]
            }
            $doc delete
            return $buckets
        }
        lsbucket {
            # s3 lsbucket /bucket/path
            regexp -line {^/([^/]+)(/\S*)$} [lindex $args 1] -> bucket path
            set xmlDoc [s3_get $path $bucket]
            set doc [dom parse $xmlDoc]
            set root [$doc documentElement]
            $doc selectNodesNamespaces "ns [$root getAttribute xmlns]"
            set files {}
            foreach file [$root selectNodes {/ns:ListBucketResult/ns:Contents}] {
                lappend files [[$file getElementsByTagName Key] asText]
            }
            $doc delete
            return $files
        }
        get {
            # usage: s3 get /bucket/object
            # eg.: s3 get /myBucket/images/armadillo.jpg 
        }
        default {
            error "Unknown s3 command"
        }
    }
}
