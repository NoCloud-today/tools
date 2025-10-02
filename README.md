# Various tools

## Ubuntu setup script
```bash
wget https://raw.githubusercontent.com/NoCloud-today/tools/main/ubuntu_setup.sh && sudo bash ubuntu_setup.sh
```

For leaving ssh config as is: 
```bash
wget https://raw.githubusercontent.com/NoCloud-today/tools/main/ubuntu_setup.sh && sudo bash ubuntu_setup.sh -no-ssh
```

## ToDo:
- ubuntu_setup - add optional Docker install (`curl https://get.docker.com/ | sh`)
- gpg stream to rclone, without intermediate files ( [rclone ref]([url](https://forum.rclone.org/t/how-can-i-stream-to-a-remote/29754/2)), [gpg ref]([url](https://lists.gnupg.org/pipermail/gnupg-users/2008-December/035168.html)) )
