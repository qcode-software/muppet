package provide muppet 1.0
package require qcode 1.8
namespace eval muppet {}

proc muppet::postgresql_install { args } {
    #| Vanilla postgresql install, postgresql prompt install
    args $args -version 8.4 --
    if { $version eq "9.1" } {
        install -release squeeze-backports postgresql-${version} postgresql-contrib-${version}
    } else {
        install postgresql-${version} postgresql-contrib-${version}
    }
    postgresql_psqlrc_install -version $version
}

proc muppet::postgresql_db_exists {db_name} {
    #| Check if db already exists.
    set result [sh sudo -u postgres -s psql -c "select datname from pg_database;"]
    return [regexp -line "(^| *)${db_name}\$" $result]
}

proc muppet::postgresql_db_create { args } {
    #| Create pg db as pg user $db_owner.
    # Create system user $db_owner and load pgcrypto library into db.
    args $args -version 8.4 -- db_name db_owner
    user_add $db_owner
    if { ![postgresql_db_exists $db_name] } {
	sh sudo -u $db_owner -s createdb $db_name
        if { $version eq "8.4" } {
	    sh sudo -u $db_owner -s psql -d $db_name -f [sh pg_config --sharedir]/contrib/pgcrypto.sql
	    sh sudo -u $db_owner -s createlang plpgsql $db_name
        } elseif { $version eq "9.1" } {
	    sh sudo -u $db_owner -s psql -d $db_name -c "create extension pgcrypto;"
        } else {
            error "Unsupported postgresql version $version"
        }
    }
}

proc muppet::postgresql_table_exists {db_name schema table} {
    #| Check if a table already exists.
    set result [sh sudo -u postgres -s psql -d $db_name -c [db_qry_parse "select tablename from pg_tables where tablename=:table and schemaname=:schema;"]]
    return [regexp -line "(^| *)${table}\$" $result]
}

proc muppet::postgresql_user_exists {user_name} {
    #| Check if pg user already exists.
    set result [sh sudo -u postgres -s psql -c "select rolname from pg_roles;"]
    return [regexp -line "(^| *)${user_name}\$" $result]
}

proc muppet::postgresql_user_create {args} {
    #| Create pg user.
    # Escalate privaledges if user already exists.
    args $args -login -superuser -replication -- user

    if { ![postgresql_user_exists $user] } {
	set command "CREATE ROLE \"$user\"" 
    } else {
	set command "ALTER ROLE \"$user\""
    }
    if { [info exists login] } {
	append command " LOGIN"
    }
    if { [info exists superuser] } {
	append command " SUPERUSER"
    }
    if { [info exists replication] } {
	append command " REPLICATION"
    }

    sh sudo -u postgres -s psql -c $command
}

proc muppet::postgresql_admins_create {args} {
    #| Create multiple pg admin users.
    # Usage postgresql_admin_create user_name ?user_name? ?user_name?.
    foreach user $args {
	postgresql_user_create -login -superuser $user
    } 
}

proc muppet::postgresql_user_password {user {password ""}} {
    #| Set pg user's password.
    # If password is not supplied or empty then prompt for it.
    while { [eq $password ""] } {
	puts "Enter Password For Postgresql User \"$user\" (Press Enter To Use Current Password):"	 
	if {  [gets stdin input] > 0 } {
	    puts "Confirm Password For Postgresql User \"$user\":"
	    if {  [eq [gets stdin] $input] } {
		set password $input
		break
	    } else {
		puts "Passwords Do Not Match, Please Try Again"
	    }
	} else {
	    return
	} 
    }
    sh sudo -u postgres -s psql -c "ALTER USER \"$user\" WITH PASSWORD '[string map {' ''} $password]'"
}

proc muppet::postgresql_psqlrc_install { args } {
    args $args -version 8.4 --
    if { [catch {exec which pg_config}] || [catch {exec pg_config --sysconfdir}] } {
        if {$version eq "9.1"} {
            install -release squeeze-backports libpq-dev
        } else {
            install libpq-dev
        }
    }
    ############## capture stdout from sh
    set config_dir [string trim [sh pg_config --sysconfdir]]
    if { ![file exists $config_dir] } {
        sh mkdir -p $config_dir
    }
    file_write "${config_dir}/psqlrc" [postgresql_psqlrc] 0644
}

proc muppet::postgresql_psqlrc {} {
    global env
    set PROMPT1 "%/ \[$env(ENVIRONMENT)\]%R%# "
    return "\\set PROMPT1 '$PROMPT1'"
}

proc muppet::postgresql_tuning {args} {
    #| update postgresql.conf tuning parameters and restart postgresql.
    # USAGE: postgresql_tuning -version 9.1 max_connections 100 shared_buffers 24MB maintenance_work_memory 16MB work_mem 1MB
    args $args -version 8.4 -- args
    set filename /etc/postgresql/${version}/main/postgresql.conf    
    set postgresql_conf [config_update $filename {*}$args]
    file_write $filename $postgresql_conf 0644
    service postgresql restart
}
