package provide muppet 1.2.0
package require qcode
namespace eval muppet {}

proc muppet::apache_vhost.conf { listen port docroot } {
    return [subst -nocommands {<VirtualHost ${listen}:${port}>
        ServerAdmin webmaster@localhost

        DocumentRoot $docroot
        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory $docroot>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride None
                Order allow,deny
                allow from all
        </Directory>

        ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
        <Directory "/usr/lib/cgi-bin">
                AllowOverride None
                Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
                Order allow,deny
                Allow from all
        </Directory>

        ErrorLog \${APACHE_LOG_DIR}/error.log

        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn

        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
}]
}

proc muppet::apache_ports.conf { vhostdict } {
    set output {}
    foreach vhost [dict keys $vhostdict] {
        set argnames [args2vars [dict get $vhostdict $vhost]]
        default port 80
        default listen 127.0.0.1
        default docroot /var/www
        append output [subst -nocommands {
NameVirtualHost ${listen}:${port}
Listen ${listen}:${port}
        }]
        unset port listen docroot
    }
    return [subst -nocommands {# If you just change the port or add more ports here, you will likely also
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default
# This is also true if you have upgraded from before 2.2.9-3 (i.e. from
# Debian etch). See /usr/share/doc/apache2.2-common/NEWS.Debian.gz and
# README.Debian.gz

$output

<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/apache2/sites-available/default-ssl
    # to <VirtualHost *:443>
    # Server Name Indication for SSL named virtual hosts is currently not
    # supported by MSIE on Windows XP.
    Listen 443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
}]
}

proc muppet::apache_vhosts { vhostdict } {
    foreach vhost [dict keys $vhostdict] {
        set argnames [args2vars [dict get $vhostdict $vhost]]
        default port 80
        default listen 127.0.0.1
        default docroot /var/www
        file_write /etc/apache2/sites-available/${vhost} [apache_vhost.conf $listen $port $docroot] 0644
        file_link /etc/apache2/sites-enabled/${vhost} /etc/apache2/sites-available/${vhost}
        if { ![file exists $docroot]} {
            # TODO should we set ownership to www-data?
            sh mkdir -p $docroot
        }
        unset port listen docroot
    }
    file_write /etc/apache2/ports.conf [apache_ports.conf $vhostdict] 0644

}

proc muppet::apache_install { vhostdict } {
    # Top level proc
    # Called like so:
    # apache_install { 
    #    test  {port 8888 listen 127.0.0.1 docroot /var/www/test}
    #    test2 {port 8889 listen 127.0.0.1 docroot /var/www/test2}
    # }
    # Doesn't support SSL at the moment.

    install apache2
    apache_vhosts $vhostdict

    # Be careful of this in preexisting installations
    if { [file exists "/etc/apache2/sites-enabled/000-default"] } {
        file delete "/etc/apache2/sites-enabled/000-default"
    }

    service apache2 restart

}

proc muppet::apache_test {} {
    apache_install { 
        test  {listen 10.0.0.1}
        test2 {port 8889 listen 127.0.0.1 docroot /var/www/test2}
    }
}

