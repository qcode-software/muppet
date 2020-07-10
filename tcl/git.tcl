namespace eval muppet {
    namespace export *
} 

proc muppet::git_rev_parse {git_project_url revision} {
    #| Return full commit hash corresponding to revision.
    #| revision can be a partial commit hash, tag or branch.
    set temp_dir /tmp/git_rev_parse
    sh rm -rf $temp_dir
    sh sudo -u nsd -s git clone $git_project_url $temp_dir
    regexp {^([a-z0-9]+)\n$} [sh sudo -u nsd -s git --git-dir=${temp_dir}/.git --work-tree=${temp_dir} rev-parse $revision] -> commit
    sh rm -rf $temp_dir
    if { $commit eq "" } {
	error "Could not find commit using \"$revision\""
    }
    return $commit
}

proc muppet::git_nsd_update {git_project_url revision} {
    #| "Export" the specified revision of a git project to /home/nsd/ and update project's symbolic link to point to this revision
    #| revision can be a partial commit hash, tag or branch.
    #| Example usage: 
    #| git_nsd_update git@github.krypton:qcode-software/qcode-tcl.git master
    regexp {/([^/]+).git$} $git_project_url -> project
    set commit [git_rev_parse $git_project_url $revision]

    # Checkout specified revision and remove .git & .gitignore files
    set export_dir /home/nsd/${project}.$commit    
    if { ![file exists $export_dir] } {
        sh sudo -u nsd -s git clone $git_project_url $export_dir
	sh sudo -u nsd -s git --git-dir=${export_dir}/.git --work-tree=${export_dir} checkout $commit
	sh sudo -u nsd -s rm -rf ${export_dir}/.git
	sh sudo -u nsd -s rm -rf ${export_dir}/.gitignore
    }
    sh ln -sfT  /home/nsd/${project}.$commit /home/nsd/$project
    return "Commit \"$commit\" of Project \"$project\" has successfully been checked out"
}
