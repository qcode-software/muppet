package provide muppet 1.0
package require qcode 1.17
package require sha1
package require md5
package require base64
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

proc muppet::s3_auth_headers { args } {
    #| Constructs the required s3 authentication header for the request type in question.
    #| See: http://docs.aws.amazon.com/AmazonS3/latest/dev/RESTAuthentication.html
 
    qc::args $args -content_type "" -content_md5 "" -- verb path bucket 
    # eg s3_auth_headers -content_type image/jpeg -content_md5 xxxxxx PUT /pics/image.jpg mybucket

    # AWS credentials
    set access_key [dict get [qc::param aws] access_key]
    set secret_access_key [dict get [qc::param aws] secret_access_key]

    set date [qc::format_timestamp_http now]
   
    if { $bucket ne "" } {
        set canonicalized_resource "/$bucket[qc::url_path $path]"
    } else {
        set canonicalized_resource "/"
    }
    puts "cr = $canonicalized_resource"

    # TODO ignoring canonicalized_amz_headers
    set canonicalized_amz_headers  ""

    # Contruct string for hmac signing
    set string_to_sign "$verb"
    lappend string_to_sign "$content_md5"  
    lappend string_to_sign "$content_type"  
    lappend string_to_sign "$date"
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

proc muppet::s3_get { bucket path } {
    #| Construct the http GET request to S3 including auth headers
    puts "path - $path bucket = $bucket"
    set headers [s3_auth_headers GET $path $bucket] 
    puts "url = [s3_url $bucket]$path"
    set result [qc::http_get -headers $headers [s3_url $bucket]$path]
    puts $result
    return $result
}

proc muppet::s3_save { bucket path filename } {
    #| Construct the http SAVE request to S3 including auth headers
    puts "path - $path bucket = $bucket"
    set headers [s3_auth_headers GET $path $bucket] 
    puts "url = [s3_url $bucket]$path"
    return [qc::http_save -headers $headers [s3_url $bucket]$path $filename]
}

proc muppet::s3_put { bucket filename path } {
    #| Construct the http PUT request to S3 including auth headers
    puts "path - $path bucket = $bucket"
    set content_type [qc::mime_type_guess $filename]
    # content_md5 header allows AWS to return an error if the file received has a different md5
    set content_md5 [::base64::encode [::md5::md5 -file $filename]]
    # Authentication value needs to use content_* values for hmac signing
    set headers [s3_auth_headers -content_type $content_type -content_md5 $content_md5 PUT $path $bucket] 
    lappend headers Content-Length [file size $filename]
    lappend headers Content-MD5 $content_md5
    lappend headers Content-Type $content_type
    # Stop tclcurl from stending Transfer-Encoding header
    lappend headers Transfer-Encoding {}
    puts "headers = $headers"
    puts "url = [s3_url $bucket]$path"
    return [qc::http_put -headers $headers [s3_url $bucket]$path $filename]
}

proc string2hex s {
    binary scan $s H* hex
    regsub -all (..) $hex { \1}
 }

proc muppet::s3 { args } {
    #| Access Amazon S3 buckets via REST API
    # Usage: s3 subcommand {args}
    # where subcommand is one of ls, lsbucket, put
    switch [lindex $args 0] {
        ls {
            # usage: s3 ls
	    return [muppet::xml_nodes2text [muppet::s3_xml_nodes_select [s3_get "" /] {/ns:ListAllMyBucketsResult/ns:Buckets/ns:Bucket/ns:Name/text()} ]]
        }
        lsbucket {
            # usage: s3 lsbucket bucket {prefix}
            # s3 lsbucket myBucket Photos/
            if { [llength $args] == 3 } {
                # prefix is specified
                set xmlDoc [s3_get [lindex $args 1] "/?prefix=[lindex $args 2]"]
            } else {
                set xmlDoc [s3_get [lindex $args 1] /]
            }
	    return [muppet::xml_nodes2text [muppet::s3_xml_nodes_select $xmlDoc {/ns:ListBucketResult/ns:Contents/ns:Key} ]]
        }
        get {
            # usage: s3 get bucket remote_path local_path
            s3_save {*}[lrange $args 1 end]
        }
        put {
            # usage: s3 put bucket local_path remote_path
            s3_put {*}[lrange $args 1 end]
        }
        default {
            error "Unknown s3 command. Must be one of ls, lsbucket or put."
        }
    }
}

proc muppet::s3_xml_select { xmlDoc xpath } {
    #| Overly simplistic proc to return a list of values from a xmlDoc
    # Could be extended to return more complex data structures like ldict or multimaps
    # containing several tags
    set doc [dom parse $xmlDoc]
    set root [$doc documentElement]
    $doc selectNodesNamespaces "ns [$root getAttribute xmlns]"
    return [$root selectNodes $xpath] 
}

proc muppet::s3_xml_nodes2ldict { node_list } {
    set ldict [list]
    foreach node $node_list {
        set dict {}
        foreach child [$node childNodes] {
            dict set dict [$child nodeName] [$child asText]
        }
        lappend ldict $dict
    }
    return $ldict
}

proc muppet::xml_nodes2text { list } {
    set result {}
    foreach node $list {
        lappend result [$node asText]
    }
    return $result
}
