ssh_repo_access
====================

Usage
--------------------------
``` ssh_repo_access host_shortname user host_domain ```

Example
--------------------------
* ```muppet ssh_repo_access private john debian.domain.co.uk```

Will look for an encrypted private key at a remote location and save it to ``` /root/.ssh/ ```
The encrypted key will be decypted on disk requiring the encryption key to be entered by the user.
An ssh config will be added as follows to use the saved private key to access this repo:

```
        Host private
        HostName debian.domain.co.uk
        User john
        IdentityFile ~/.ssh/john.key
        
```
and a sources.list entry will be added
```
deb ssh://private:/home/john/ squeeze main
```

Assumptions
--------------------------
Assumes that this key has already been authorized access to john@debian.domain.co.uk
