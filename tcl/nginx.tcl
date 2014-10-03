package provide muppet 1.2.7
package require qcode
namespace eval muppet {}

proc muppet::nginx_defaults {} {
    return {worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    server_names_hash_bucket_size 64;
    proxy_buffering off;
    gzip on;
    gzip_types text/plain text/xml text/css text/javascript application/json application/x-javascript;

    access_log	off;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
}
}

proc muppet::nginx_server { sitename conf } {
        file_write /etc/nginx/sites-available/$sitename $conf 0644
        file_link /etc/nginx/sites-enabled/$sitename /etc/nginx/sites-available/$sitename
}
