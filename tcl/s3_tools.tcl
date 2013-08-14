package provide muppet 1.0
package require qcode
package require sha1
package require md5
package require base64
package require tdom
package require fileutil
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
            # otherwise, drop the query part
            set canonicalized_resource "/$bucket[qc::url_path $path]"
        }
    } else {
        set canonicalized_resource "/"
    }

    # TODO ignoring canonicalized_amz_headers
    set canonicalized_amz_headers  ""

    # Contruct string for hmac signing
    set string_to_sign "$verb"
    lappend string_to_sign "$content_md5"  
    lappend string_to_sign "$content_type"  
    lappend string_to_sign "$date"
    lappend string_to_sign "${canonicalized_amz_headers}${canonicalized_resource}"
    set string_to_sign [join $string_to_sign \n]
    set signature [::base64::encode [::sha1::hmac -bin $secret_access_key $string_to_sign]]
    set authorization "AWS ${access_key}:$signature"

    return [list Host [s3_url $bucket] Date $date Authorization $authorization]
}

proc muppet::s3_get { bucket path } {
    #| Construct the http GET request to S3 including auth headers
    set headers [s3_auth_headers GET $path $bucket] 
    set result [qc::http_get -headers $headers [s3_url $bucket]$path]
    return $result
}

proc muppet::s3_post { bucket path {data ""}} {
    #| Construct the http POST request to S3 including auth headers
    set headers [s3_auth_headers POST $path $bucket] 
    lappend headers Content-Type {}
    if { $data ne "" } {
        set result [qc::http_post -headers $headers -data $data [s3_url $bucket]$path]
    } else {
        set result [qc::http_post -headers $headers [s3_url $bucket]$path]
    }
    return $result
}

proc muppet::s3_delete { bucket path } {
    #| Construct the http DELETE request to S3 including auth headers
    set headers [s3_auth_headers DELETE $path $bucket] 
    set result [qc::http_delete -headers $headers [s3_url $bucket]$path]
    return $result
}

proc muppet::s3_save { bucket path filename } {
    #| Construct the http SAVE request to S3 including auth headers
    set headers [s3_auth_headers GET $path $bucket] 
    return [qc::http_save -headers $headers [s3_url $bucket]$path $filename]
}

proc muppet::s3_put { args } {
    #| Construct the http PUT request to S3 including auth headers
    # s3_put ?-header 0 ?-data ? ?-infile ? bucket path 
    qc::args $args -header 0 -data ? -infile ? bucket path 
    if { [info exists data]} {
        set content_type "application/octet-stream"
        set content_md5 [::base64::encode [::md5::md5 $data]]
        set data_size [string length $data]
    } elseif { [info exists infile]} {
        set content_type [qc::mime_type_guess $infile]
        set content_md5 [::base64::encode [::md5::md5 -file $infile]]
        set data_size [file size $infile]
    } else {
        error "muppet::s3_put: 1 of -data or -infile must be specified"
    }
    # content_md5 header allows AWS to return an error if the file received has a different md5
    # Authentication value needs to use content_* values for hmac signing
    set headers [s3_auth_headers -content_type $content_type -content_md5 $content_md5 PUT $path $bucket] 
    lappend headers Content-Length $data_size
    lappend headers Content-MD5 $content_md5
    lappend headers Content-Type $content_type
    # Stop tclcurl from stending Transfer-Encoding header
    lappend headers Transfer-Encoding {}
    lappend headers Expect {}
    # Have timeout values roughly in proportion to the filesize
    # In this case allowing 100,000 bytes per second
    set timeout [expr {$data_size/100000}]
    if { [info exists data] } {
        # data
        return [qc::http_put -header $header -headers $headers -timeout $timeout -data $data [s3_url $bucket]$path]
    } else {
        # file
        return [qc::http_put -header $header -headers $headers -timeout $timeout -infile $infile [s3_url $bucket]$path]
    }
}

proc muppet::s3 { args } {
    #| Access Amazon S3 buckets via REST API
    # Usage: s3 subcommand {args}
    switch [lindex $args 0] {
        ls {
            # usage: s3 ls
            set nodes [muppet::s3_xml_select [muppet::s3_get "" /] {/ns:ListAllMyBucketsResult/ns:Buckets/ns:Bucket}]
            return [qc::lapply muppet::s3_xml_node2dict $nodes]
        }
        lsbucket {
            # usage: s3 lsbucket bucket {prefix}
            # s3 lsbucket myBucket Photos/
            if { [llength $args] == 1 || [llength $args] > 3 } {
                error "Missing argument. Usage: muppet::s3 lsbucket mybucket {prefix}"
            } elseif { [llength $args] == 3 }  {
                # prefix is specified
                set xmlDoc [muppet::s3_get [lindex $args 1] "/?prefix=[lindex $args 2]"]
            } else {
                set xmlDoc [muppet::s3_get [lindex $args 1] /]
            }
	    return [qc::lapply muppet::s3_xml_node2dict [muppet::s3_xml_select $xmlDoc {/ns:ListBucketResult/ns:Contents}]]
        }
        get {
            # usage: s3 get bucket remote_path local_path
            muppet::s3_save {*}[lrange $args 1 end]
        }
        put {
            # usage: s3 put bucket local_path remote_path
            # 5GB limit
            lassign $args -> bucket local_path remote_path
            if { [file size $local_path] > [expr {1024*1024*5}]} { 
                # Use multipart upload
                muppet::s3 upload $bucket $local_path $remote_path
            } else {
                muppet::s3_put -infile $local_path $bucket $remote_path
            }
        }
        upload {
            switch [lindex $args 1] {
                init {
                    # s3 upload init bucket remote_path
                    lassign $args -> -> bucket remote_path
                    set upload_dict [muppet::s3_xml_node2dict [muppet::s3_xml_select [muppet::s3_post $bucket ${remote_path}?uploads] {/ns:InitiateMultipartUploadResult}]]
                    set upload_id [dict get $upload_dict UploadId]
                    puts "Upload init for $remote_path to $bucket."
                    puts "Upload_id: $upload_id"
                    return $upload_id
                }
                abort {
                    # s3 upload abort bucket remote_path upload_id
                    lassign $args -> -> bucket remote_path upload_id
                    return [s3_delete $bucket ${remote_path}?uploadId=$upload_id]
                }
                ls {
                    # usage: s3 upload ls bucket 
                    lassign $args -> -> bucket
                    return [qc::lapply muppet::s3_xml_node2dict [muppet::s3_xml_select [muppet::s3_get $bucket /?uploads] {/ns:ListMultipartUploadsResult/ns:Upload}]]
                }
                lsparts {
                    # usage: s3 upload lsparts bucket remote_path upload_id
                    lassign $args -> -> bucket remote_path upload_id
                    return [qc::lapply muppet::s3_xml_node2dict [muppet::s3_xml_select [muppet::s3_get $bucket ${remote_path}?uploadId=$upload_id] {/ns:ListPartsResult/ns:Part}]]
                }
                cleanup {
                    # usage: s3 upload cleanup bucket 
                    # aborts any unfinished uploads for bucket
                    lassign $args -> -> bucket 
                    foreach dict [muppet::s3 upload ls $bucket] {
                        muppet::s3 upload abort $bucket "/[dict get $dict Key]" [dict get $dict UploadId]
                    }
                }
                complete {
                    # usage: s3 upload complete bucket remote_path upload_id etag_dict
                    lassign $args -> -> bucket remote_path upload_id etag_dict
                    set xml {<CompleteMultipartUpload>}
                    foreach PartNumber [dict keys $etag_dict] {
                        set ETag [dict get $etag_dict $PartNumber]
                        lappend xml "<Part>[qc::xml_from PartNumber ETag]</Part>"
                    }
                    lappend xml {</CompleteMultipartUpload>}
                    puts "Completing Upload to $remote_path in $bucket."
                    return [muppet::s3_post $bucket ${remote_path}?uploadId=$upload_id [join $xml \n]]
                }
                send {
                    # Perform upload
                    # usage: s3 upload send bucket local_path remote_path upload_id
                    lassign $args -> -> bucket local_path remote_path upload_id
                    # bytes
                    set part_size [expr {1024*1024*5}]
                    set retries 3
                    set part_index 1
                    set etag_dict [dict create]
                    set file_size [file size $local_path]
                    # Timeout - allow 10240 B/s
                    global s3_timeout
                    set s3_timeout($upload_id) false
                    set timeout_period [expr {($file_size/10240)*1000}]
                    puts "Timeout set as $timeout_period ms"
                    set id [after $timeout_period [list set s3_timeout($upload_id) true]]
                    set num_parts [expr {round(ceil($file_size/double($part_size)))}]
                    set fh [open $local_path r]
                    fconfigure $fh -translation binary
                    while { !$s3_timeout($upload_id) &&  $part_index <= $num_parts } {

                        # Use temp file to upload part from - inefficient, but posting binary data directly from http_put not yet working.
                        set tempfile [::fileutil::tempfile]
                        set tempfh [open $tempfile w]
                        fconfigure $tempfh -translation binary
                        puts "Uploading ${local_path}: Sending part $part_index of $num_parts"
                        puts -nonewline $tempfh [read $fh $part_size]
                        close $tempfh

                        set success false 
                        set attempt 1
                        while { !$s3_timeout($upload_id) && !$success } {
                            try {
                                set response [muppet::s3_put -header 1 -infile $tempfile $bucket ${remote_path}?partNumber=${part_index}&uploadId=$upload_id]
                                set success true
                            } {
                                puts stderr "Failed - retrying part $part_index of ${num_parts}... "
                                after [expr {int(pow(2,$attempt)-1)}]
                                incr attempt
                            }
                        }
                        if { $s3_timeout($upload_id) } { 
                            #TODO should we abort or leave for potential recovery later?
                            try {
                                muppet::s3 upload abort $bucket $remote_path $upload_id
                            }
                            error "Upload timed out"
                        }
                        regexp -line -- {^ETag: "(\S+)"\s*$} $response match etag
                      
                        dict set etag_dict $part_index $etag
                        file delete $tempfile
                        incr part_index
                    }
                    close $fh
                    after cancel $id
                    unset s3_timeout($upload_id)
                    return $etag_dict

                }
                default {
                    # Top level multipart upload
                    # usage: s3 upload bucket local_path remote_path
                    # TODO could be extended to retry upload part failures
                    lassign $args -> bucket local_path remote_path 
                    set upload_id [muppet::s3 upload init $bucket $remote_path]
                    set etag_dict [muppet::s3 upload send $bucket $local_path $remote_path $upload_id]
                    muppet::s3 upload complete $bucket $remote_path $upload_id $etag_dict
                }
            }
        }
        delete {
            # usage: s3 delete bucket remote_filename
            muppet::s3_delete {*}[lrange $args 1 end]
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
