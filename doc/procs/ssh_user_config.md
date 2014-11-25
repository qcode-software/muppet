Usage
--------------------------
``` ssh_user_config set|update|delete user host ?config_name value? ?config_name value? ```

Example
--------------------------
* ```ssh_user_config set root muppet_repo HostName debian.qcode.co.uk User muppet IdentityFile ~/.ssh/id_muppet_rsa```

will add the following to ~/.ssh/config in root's home dir.

```
        Host muppet_repo
        Hostname debian.qcode.co.uk
        User muppet
        IdentityFile ~/.ssh/id_muppet_rsa
   
```
