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
        # Is there a subresource specified?
        set subresources [list "acl" "lifecycle" "location" "logging" "notification" "partNumber" "policy" "requestPayment" "torrent" "uploadId" "uploads" "versionId" "versioning" "versions" "website"]
        if { [regexp {^[^\?]+\?([A-Za-z]+).*$} $path -> resource] && [qc::in $subresources $resource] } {
            set canonicalized_resource "/${bucket}${path}"
        } else {
            set canonicalized_resource "/$bucket[qc::url_path $path]"
        }
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
    return $result
}

proc muppet::s3_post { bucket path {data ""}} {
    #| Construct the http POST request to S3 including auth headers
    puts "path - $path bucket = $bucket"
    set headers [s3_auth_headers POST $path $bucket] 
    lappend headers Content-Type {}
    puts "url = [s3_url $bucket]$path"
    if { $data ne "" } {
        set result [qc::http_post -headers $headers -data $data [s3_url $bucket]$path]
    } else {
        set result [qc::http_post -headers $headers [s3_url $bucket]$path]
    }
    return $result
}

proc muppet::s3_delete { bucket path } {
    #| Construct the http DELETE request to S3 including auth headers
    puts "path - $path bucket = $bucket"
    set headers [s3_auth_headers DELETE $path $bucket] 
    puts "url = [s3_url $bucket]$path"
    set result [qc::http_delete -headers $headers [s3_url $bucket]$path]
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
    set file_size [file size $filename]
    lappend headers Content-Length $file_size
    lappend headers Content-MD5 $content_md5
    lappend headers Content-Type $content_type
    # Stop tclcurl from stending Transfer-Encoding header
    lappend headers Transfer-Encoding {}
    puts "headers = $headers"
    puts "url = [s3_url $bucket]$path"
    # Have timeout values roughly in proportion to the filesize
    # In this case allowing 100,000 bytes per second
    set timeout [expr {$file_size/100000}]
    return [qc::http_put_file -headers $headers -timeout $timeout [s3_url $bucket]$path $filename]
}

proc muppet::s3_put_data { bucket path data } {
    # TODO temp proc to test method
    #| Construct the http PUT request to S3 including auth headers
    puts "path - $path bucket = $bucket"
    set content_type "*/*"
    # content_md5 header allows AWS to return an error if the file received has a different md5
    set content_md5 [::base64::encode [::md5::md5 $data]]
    # Authentication value needs to use content_* values for hmac signing
    set headers [s3_auth_headers -content_type $content_type -content_md5 $content_md5 PUT $path $bucket] 
    set data_size [string bytelength $data]
    lappend headers Content-Length $data_size
    lappend headers Content-MD5 $content_md5
    lappend headers Content-Type $content_type
    # Stop tclcurl from stending Transfer-Encoding header
    lappend headers Transfer-Encoding {}
    puts "headers = $headers"
    puts "url = [s3_url $bucket]$path"
    # Have timeout values roughly in proportion to the filesize
    # In this case allowing 100,000 bytes per second
    set timeout [expr {$data_size/100000}]
    return [qc::http_put_data -headers $headers -timeout $timeout [s3_url $bucket]$path $data]
}

proc string2hex s {
    binary scan $s H* hex
    regsub -all (..) $hex { \1}
 }

proc muppet::s3 { args } {
    #| Access Amazon S3 buckets via REST API
    # Usage: s3 subcommand {args}
    switch [lindex $args 0] {
        ls {
            # usage: s3 ls
            set nodes [muppet::s3_xml_select [s3_get "" /] {/ns:ListAllMyBucketsResult/ns:Buckets/ns:Bucket}]
            return [qc::lapply muppet::s3_xml_node2dict $nodes]
        }
        lsbucket {
            # usage: s3 lsbucket bucket {prefix}
            # s3 lsbucket myBucket Photos/
            if { [llength $args] == 1 || [llength $args] > 3 } {
                error "Missing argument. Usage: muppet::s3 lsbucket mybucket {prefix}"
            } elseif { [llength $args] == 3 }  {
                # prefix is specified
                set xmlDoc [s3_get [lindex $args 1] "/?prefix=[lindex $args 2]"]
            } else {
                set xmlDoc [s3_get [lindex $args 1] /]
            }
	    return [qc::lapply muppet::s3_xml_node2dict [muppet::s3_xml_select $xmlDoc {/ns:ListBucketResult/ns:Contents}]]
        }
        get {
            # usage: s3 get bucket remote_path local_path
            s3_save {*}[lrange $args 1 end]
        }
        put {
            # usage: s3 put bucket local_path remote_path
            # 5GB limit
            s3_put {*}[lrange $args 1 end]
        }
        upload {
            switch [lindex $args 1] {
                init {
                    # s3 upload start bucket remote_path
                    set bucket [lindex $args 2]
                    set remote_path [lindex $args 3]
                    set upload_dict [muppet::s3_xml_node2dict [muppet::s3_xml_select [s3_post $bucket ${remote_path}?uploads] {/ns:InitiateMultipartUploadResult}]]
                    return [dict get $upload_dict UploadId]
                }
                abort {
                    # s3 upload abort bucket remote_path upload_id
                    set bucket [lindex $args 2]
                    set remote_path [lindex $args 3]
                    set upload_id [lindex $args 4]
                    return [s3_delete $bucket ${remote_path}?uploadId=$upload_id]
                }
                ls {
                    # usage: s3 upload ls bucket 
                    set bucket [lindex $args 2]
                    return [qc::lapply muppet::s3_xml_node2dict [muppet::s3_xml_select [s3_get $bucket /?uploads] {/ns:ListMultipartUploadsResult/ns:Upload}]]
                }
                lsparts {
                    # usage: s3 upload lsparts bucket remote_path upload_id
                    set bucket [lindex $args 2]
                    set remote_path [lindex $args 3]
                    set upload_id [lindex $args 4]
                    return [qc::lapply muppet::s3_xml_node2dict [muppet::s3_xml_select [s3_get $bucket ${remote_path}?uploadId=$upload_id] {/ns:ListPartsResult/ns:Part}]]
                }
                complete {
                    # usage: s3 upload complete bucket remote_path upload_id
                    set bucket [lindex $args 2]
                    set remote_path [lindex $args 3]
                    set upload_id [lindex $args 4]
                    set xml {<CompleteMultipartUpload>}
                    foreach dict [muppet::s3 upload lsparts $bucket $remote_path $upload_id] {
                        lappend xml "<Part>[qc::dict2xml [qc::dict_subset $dict PartNumber ETag]]</Part>"
                    }
                    lappend xml {</CompleteMultipartUpload>}
                    return [s3_post $bucket ${remote_path}?uploadId=$upload_id [join $xml \n]]
                }
                default {
                    # Perform upload
                    # usage: s3 upload bucket local_path remote_path upload_id
                    set bucket [lindex $args 1]
                    set local_path [lindex $args 2]
                    set remote_path [lindex $args 3]
                    set upload_id [lindex $args 4]
                    # bytes
                    set part_size [expr {1024*1024*10}]
                    set part_index 1
                    set file_size [file size $local_path]
                    if {$file_size < [expr {1024*1024*5}]} { error "AWS requires a file size of at least 5MB for multipart upload." }
                    set num_parts [expr {round(ceil($file_size/"$part_size.0"))}]
                    set fh [open $local_path r]
                    fconfigure $fh -translation binary
                    while { $part_index <= $num_parts } {
                        set data [read $fh $part_size]
                        s3_put_data $bucket ${remote_path}?partNumber=${part_index}&uploadId=$upload_id $data
                        incr part_index
                    }
                    close $fh
                }
            }
        }
        delete {
            # usage: s3 delete bucket remote_filename
            s3_delete {*}[lrange $args 1 end]
        }
        default {
            error "Unknown s3 command. Must be one of ls, lsbucket, get, put or delete."
        }
    }
}

proc muppet::s3_xml_select { xmlDoc xpath} {
    #| Returns xml nodes specified by the supplied xpath.
    # any namespace specified in the xmlns attribute is mapped to "ns" for use in the xpath query.
    set doc [dom parse $xmlDoc]
    set root [$doc documentElement]
    if { [$root hasAttribute xmlns] } {
        $doc selectNodesNamespaces "ns [$root getAttribute xmlns]"
    }
    return [$root selectNodes $xpath] 
}

proc muppet::s3_xml_node2dict { node } {
    #| Converts an XML tdom node into a dict.
    # Use muppet::s3_xml_select to select suitable nodes with non-repeating elements
    set dict ""
    set nodes [$node childNodes]
    foreach node $nodes {
        if { [llength [$node childNodes]] > 1 \
           || ([llength [$node childNodes]] == 1 \
              && [ne [[$node firstChild] nodeType] TEXT_NODE] ) } {
            lappend dict [$node nodeName] [muppet:::s3_xml_node2dict $node]
        }  elseif { [llength [$node childNodes]] == 0 } {
            # empty node
            lappend dict [$node nodeName] {}
        } else {
            lappend dict [$node nodeName] [$node asText]
        }
    }
    return $dict
}
