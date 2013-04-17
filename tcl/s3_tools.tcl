package provide muppet 1.0
package require qcode 1.17
namespace eval muppet {
    namespace export *
} 

proc s3_url {
    return s3.amazonaws.com
}

proc s3_headers { request bucket path } {
    set access_key [dict get [qc::param aws] access_key]
    set secret_access_key [dict get [qc::param aws] secret_access_key]
    
    if { $bucket ne "" } {
        set string_to_sign "/$bucket[qc::url_path $path]"
    } else {
        set string_to_sign "/"
    }




    return "Host [s3_url] Date [qc::format_timestamp_http now] Authorization $s3_auth" 
}


proc s3_get { path {bucket ""} } {
    set headers [s3_headers GET $bucket $path] 
    
    
}

proc s3 { args } {
    switch [lindex $args 0] {
        ls {
	    return [s3_get /]
        }
        default {
            error "Unknown s3 command"
        }
    }
}
