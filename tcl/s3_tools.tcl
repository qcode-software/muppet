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

proc muppet::s3_headers { verb path bucket {content_type ""} } {
    set access_key [dict get [qc::param aws] access_key]
    #set access_key "AKIAIOSFODNN7EXAMPLE"
    set secret_access_key [dict get [qc::param aws] secret_access_key]
    #set secret_access_key "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    #set secret_access_key fakeaccesskey
    set date [qc::format_timestamp_http now]
    #set date "Tue, 27 Mar 2007 21:15:45 +0000"
   
    #TODO ignoring sub-resources for now
    if { $bucket ne "" } {
        set canonicalized_resource "/$bucket[qc::url_path $path]"
    } else {
        set canonicalized_resource "/"
    }
    puts "cr = $canonicalized_resource"

    # TODO ignoring canonicalized_amz_headers
    set canonicalized_amz_headers  ""

    set string_to_sign "$verb"
    # Content md5 (only if header is used in request)
    lappend string_to_sign ""  
    # Content type (only if header is used in request)
    if { $content_type ne "" } {
        lappend string_to_sign "$content_type"  
    } else {
        lappend string_to_sign ""  
    }
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

proc muppet::s3_get { args  } {
    qc::args $args -query "" -- bucket path 
    puts "path - $path bucket = $bucket"
    set headers [s3_headers GET $path $bucket] 
    puts "url = [s3_url $bucket]${path}$query"
    return [qc::http_get -headers $headers [s3_url $bucket]${path}$query]
}

proc muppet::s3_save { args  } {
    qc::args $args -query "" -- bucket path filename
    puts "path - $path bucket = $bucket"
    set headers [s3_headers GET $path $bucket] 
    puts "url = [s3_url $bucket]${path}$query"
    return [qc::http_save -headers $headers [s3_url $bucket]${path}$query $filename]
}

proc muppet::s3_put { args  } {
    qc::args $args -query "" -- bucket filename path
    puts "path - $path bucket = $bucket"
    set content_type [qc::mime_type_guess $filename]
    set headers [s3_headers PUT $path $bucket $content_type] 
    lappend headers Content-Length [file size $filename]
    lappend headers Content-Type $content_type
    lappend headers Transfer-Encoding {}
    puts "headers = $headers"
    puts "url = [s3_url $bucket]${path}$query"
    return [qc::http_put -headers $headers [s3_url $bucket]${path}$query $filename]
}

proc string2hex s {
    binary scan $s H* hex
    regsub -all (..) $hex { \1}
 }

proc muppet::s3 { args } {
    switch [lindex $args 0] {
        ls {
            # s3 ls
	    return [muppet::s3_xml_select_tag {/ns:ListAllMyBucketsResult/ns:Buckets/ns:Bucket} "Name" [s3_get "" /]]
        }
        lsbucket {
            # s3 lsbucket bucket {prefix}
            # s3 lsbucket myBucket /Photos
            if { [llength $args] == 3 } {
                # prefix is specified
                set xmlDoc [s3_get -query "?prefix=[lindex $args 2]" / [lindex $args 1]]
            } else {
                set xmlDoc [s3_get / [lindex $args 1]]
            }
	    return [muppet::s3_xml_select_tag  {/ns:ListBucketResult/ns:Contents} "Key" $xmlDoc ]
        }
        get {
            # usage: s3 get bucket remote_path local_path
            puts "args = $args"
            s3_save {*}[lrange $args 1 end]
        }
        put {
            # usage: s3 put bucket local_path remote_path
            s3_put {*}[lrange $args 1 end]
        }
        default {
            error "Unknown s3 command"
        }
    }
}

proc muppet::s3_xml_select_tag { node_xpath tag_to_select xmlDoc } {
    #| Overly simplistic proc to return a list of values from a xmlDoc
    # Could be extended to return more complex data structures like ldict or multimaps
    # containing several tags
    set doc [dom parse $xmlDoc]
    set root [$doc documentElement]
    $doc selectNodesNamespaces "ns [$root getAttribute xmlns]"
    set result {}
    foreach node [$root selectNodes $node_xpath] {
        lappend result [[$node getElementsByTagName $tag_to_select] asText]
    }
    $doc delete
    return $result
}
