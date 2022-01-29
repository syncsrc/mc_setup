# mc_setup
Script to install a Minecraft Java Edition server on cloud instances running Ubuntu. This script assumes the user is capable of launching an Ubuntu cloud instance, configuring cloud virtual networking, and logging in to the instance. While compatible with many free-tier cloud accounts, this script does not attempt to set any usage limits. All cloud bills resulting from the use of this script are the sole responsibility of the user.

Furthermore, this script makes no attempt to check the compatibility of mods and plugins being installed, and can provide no support for errors encountered with modded servers. Caveat emptor.

## OS Support
Ubuntu 18.04 LTS and Ubuntu 20.04 LTS. Works with both X64 and ARM64 hosts.

## Server Framework Support
Vanilla: https://mcversions.net/

Forge: https://files.minecraftforge.net/

Fabric: https://fabricmc.net/

Magma: https://magmafoundation.org/

Only select Minecraft versions and Frameworks are currently supported, additional versions for supported frameworks can be added on request. 


# Usage
```
git clone https://github.com/syncsrc/mc_setup.git
cd mc_setup/
./mc_server_setup.sh -h
```

Explaination of options provided in online help.


# Backups
Installation using this script causes a nightly backup of server data to be made in /opt/minecraft/backups/. To avoid filling up the disk, only the previous 7 daily backups are saved; older backups are removed to conserve space. Further archiving of backups is left to the user. To restore a world that was saved by the nightly backup run the following (do not use the "-a" option when restoring an existing world):

```
tar -xzvf minecraft_server.tar.gz
DIR=$(find opt/minecraft/ -type d -name "server*")
./mc_server_setup.sh -v $(cat $DIR/mc_version.txt) -m $DIR/mods.txt -p $DIR/plugins.txt -e $DIR/extra.properties
```

Check the informational script output to find the new server folder that was created, and use that in place of "SERVERDIR" in the following commands to move the old world data to the new folder:

```
sudo mv $DIR/world /opt/minecraft/SERVERDIR/
sudo chown -R minecraft.minecraft /opt/minecraft/SERVERDIR/
```

The "systemctl start" and "systemctl enable" commands from the post-install summary can now be used to launch the restored server.
