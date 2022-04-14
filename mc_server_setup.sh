#!/bin/bash
set -o pipefail
set +x  ## change to -x for debugging

### Info of player to configure as server op
### No server op will be set if defaults below are unchanged
NAME="Steve"
UUID="00000000-0000-0000-0000-000000000000"

### Maximum amount of RAM (in MB) for the Minecraft server to use. Must be > 2048
MAXRAM="4096"

### List of known installers
declare -A versions=(
    ["vanilla-1.12.2"]="https://launcher.mojang.com/v1/objects/886945bfb2b978778c3a0288fd7fab09d315b25f/server.jar"
    ["vanilla-1.13.2"]="https://launcher.mojang.com/v1/objects/3737db93722a9e39eeada7c27e7aca28b144ffa7/server.jar"
    ["vanilla-1.14.4"]="https://launcher.mojang.com/v1/objects/3dc3d84a581f14691199cf6831b71ed1296a9fdf/server.jar"
    ["vanilla-1.15.2"]="https://launcher.mojang.com/v1/objects/bb2b6b1aefcd70dfd1892149ac3a215f6c636b07/server.jar"
    ["vanilla-1.16.5"]="https://launcher.mojang.com/v1/objects/1b557e7b033b583cd9f66746b7a9ab1ec1673ced/server.jar"
    ["vanilla-1.17.1"]="https://launcher.mojang.com/v1/objects/a16d67e5807f57fc4e550299cf20226194497dc2/server.jar"
    ["vanilla-1.18.2"]="https://launcher.mojang.com/v1/objects/c8f83c5655308435b3dcf03c06d9fe8740a77469/server.jar"
    ["forge-1.12.2"]="https://maven.minecraftforge.net/net/minecraftforge/forge/1.12.2-14.23.5.2859/forge-1.12.2-14.23.5.2859-installer.jar"
    ["forge-1.16.5"]="https://maven.minecraftforge.net/net/minecraftforge/forge/1.16.5-36.2.20/forge-1.16.5-36.2.20-installer.jar"
    ["forge-1.18.2"]="https://maven.minecraftforge.net/net/minecraftforge/forge/1.18.2-40.0.48/forge-1.18.2-40.0.48-installer.jar"
    ["fabric-1.16.5"]="https://maven.fabricmc.net/net/fabricmc/fabric-installer/0.10.2/fabric-installer-0.10.2.jar"
    ["fabric-1.18.2"]="https://maven.fabricmc.net/net/fabricmc/fabric-installer/0.10.2/fabric-installer-0.10.2.jar"
    ["magma-1.12.2"]="https://github.com/magmafoundation/Magma/releases/download/v761933c-CUSTOM/Magma-761933c-STABLE-server.jar"
    ["magma-1.16.5"]="https://github.com/magmafoundation/Magma-1.16.x/releases/download/v5a1cac0/Magma-1.16.5-36.2.19-5a1cac0-STABLE-installer.jar"
)

## defaults
UPDATE="FALSE"
AUTOSTART="FALSE"
DELETE="FALSE"
EXTRAPROP="empty.file"

### Get command line options
while getopts "m:p:v:d:e:ua" arg; do
    case "${arg}" in
	m)
	    MODLIST=$(realpath ${OPTARG})
	    ;;
	p)
	    PLUGLIST=$(realpath ${OPTARG})
	    ;;
	e)
	    EXTRAPROP=$(realpath ${OPTARG})
	    ;;
	v)
	    VERSION=${OPTARG}
	    ;;
	d)
	    DELSERV=${OPTARG}
	    DELETE="TRUE"
	    ;;
	u)
	    UPDATE="TRUE"
	    ;;
	a)
	    AUTOSTART="TRUE"
	    ;;
	*)
	    echo 'Mincraft Server setup script for Ubuntu 18.04 LTS and Ubuntu 20.04 LTS'
	    echo 'Supported server versions:'
	    echo ${!versions[@]} | tr ' ' '\n' | sort
	    echo ''
	    echo 'Servers require TCP ports 30000-31000 to be accessible, ensure these'
	    echo 'are not blocked by cloud virtual network configuration.'
	    echo ''
	    echo 'Mod list file must contain one URL per line, newline terminated, suitable as input to wget -i'
	    echo ''
	    echo 'Plugin list file must contain one JAR file name and spigot resource number per line,'
	    echo 'space seperated, to be used with the spiget.org download API. Example:'
	    echo '        Manhunt-1.0-SNAPSHOT.jar 80846'
	    echo ''
	    echo 'Usage:'
	    echo '    -u         update mcrcon'
	    echo '    -a         autostart server after installation completes'
	    echo '    -v ver     minecraft version to install'
	    echo '    -e file    file containing extra server.properties options to set, e.g. pvp=false'
	    echo '    -m file    file with list of mods to install'
	    echo '    -p file    file with list of plugins to install'
	    echo '    -d dir     directory of server instance to delete, e.g. "server5"'
	    echo ''
	    echo 'Example:'
	    echo '    mc_server_setup.sh -v version [-a] [-u] [-m mods.txt] [-p plugins.txt]'
	    exit 0
	    ;;
    esac
done
shift "$((OPTIND-1))"

### Function to add server information to the server list webpage HTML
add_server_html () {
    if [ -f $1/mc_version.txt ]; then
	HOSTIP=$(wget -qO- http://ipecho.net/plain)
	SERVNUM=$(echo $1 | sed 's#/opt/minecraft/server##')
	SPORT=$((SERVNUM+30000))
	echo "<h2>Server $SERVNUM: $(cat $1/mc_version.txt)</h2>" | sudo tee -a /var/www/html/index.html > /dev/null
	echo "<p>Connect at $HOSTIP:$SPORT</p>" | sudo tee -a /var/www/html/index.html > /dev/null
	echo "<ul>" | sudo tee -a /var/www/html/index.html > /dev/null
	if [ -f $1/mods.txt ]; then
	    while read p || [[ -n $p ]]; do
		echo "<li><a href=\"$p\">$(basename $p .jar | xargs urlencode -d)</a></li>" | sudo tee -a /var/www/html/index.html > /dev/null
	    done < $1/mods.txt
	fi
	if [ -f $1/plugins.txt ]; then
	    while read p || [[ -n $p ]]; do
		PNAME=$(echo $p | cut -f 1 -d " ")
		PNUM=$(echo $p | cut -f 2 -d " ")
		echo "<li><a href=\"https://api.spiget.org/v2/resources/$PNUM/go\">$PNAME</a></li>" | sudo tee -a /var/www/html/index.html > /dev/null
	    done < $1/plugins.txt
	fi
	echo "</ul>" | sudo tee -a /var/www/html/index.html > /dev/null
	echo "<br>" | sudo tee -a /var/www/html/index.html > /dev/null
    else
	echo "WARN: Could not find mc_version.txt file for $1. Unable to add to HTML listing."
    fi
}

### Function to recreate the server list webpage
refresh_html () {
    echo "INFO: Rebuilding server info webpage at /var/www/html/index.html"
    echo "<head><title>Minecraft Server Info Page</title></head>" | sudo tee /var/www/html/index.html > /dev/null
    echo "<body>" | sudo tee -a /var/www/html/index.html > /dev/null
    set +e
    SERVLIST=$(ls -d /opt/minecraft/server* | sort -V)
    set -e
    for SERV in $SERVLIST; do
	add_server_html $SERV
    done
}


### Delete a server
if [[ $DELETE == "TRUE" ]]; then
    if [ -d /opt/minecraft/$DELSERV ]; then
	DELNUM=$(echo $DELSERV | sed 's#server##')
	read -p "ABOUT TO DELETE Server $DELNUM, $(cat /opt/minecraft/$DELSERV/mc_version.txt). ARE YOU SURE? (y/n)" -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
	    echo ""
	    echo "INFO: Stopping & disabling minecraft${DELNUM}.service"
	    sudo systemctl stop minecraft${DELNUM}.service
	    sudo systemctl disable minecraft${DELNUM}.service
	    echo "INFO: deleting /etc/cron.daily/mcbakup${DELNUM} /etc/systemd/system/minecraft${DELNUM}.service /opt/minecraft/$DELSERV"
	    sudo rm -rf /etc/cron.daily/mcbakup${DELNUM} /etc/systemd/system/minecraft${DELNUM}.service /opt/minecraft/$DELSERV
	    SPORT=$((DELNUM+30000))
	    PID=$(sudo lsof -i -P -n | grep "$SPORT" | awk '{print $2}')
	    if [ ! -z $PID ] && [ "$PID" -gt "10" ]; then
		echo "WARN: Found process $PID still bound to port $SPORT after stopping service. Killing it."
		sudo kill -9 $PID
	    fi
	fi
    else
	echo "ERROR: could not find /opt/minecraft/$DELSERV"
    fi
    refresh_html
    exit 0
fi

### Make sure a known version was supplied
if [[ "$VERSION" == "" ]]; then
    echo "ERROR: Mincraft version string must be provided."
    exit 1
elif [[ ${versions[$VERSION]} == "" ]]; then
    echo "ERROR: unknown Minecraft version. Please choose from:"
    echo ${!versions[@]} | tr ' ' '\n' | sort
    exit 1
else
    echo "INFO: installing $VERSION from ${versions[$VERSION]}"
fi

### Make sure modlist and pluglist files exists
if [[ "$MODLIST" == "" ]]; then
    if [[ "$VERSION" =~ "forge" ]] || [[ "$VERSION" =~ "fabric" ]]; then
	echo "ERROR: no modlist was supplied for $VERSION, did you mean to install Vanilla?"
	exit 1
    else
	MODLIST=""
    fi
else
    if [[ ! -f "$MODLIST" ]]; then
        echo "ERROR: could not find modlist file."
	exit 1
    else
	echo "INFO: using mods from $MODLIST"
    fi
fi
if [[ "$PLUGLIST" == "" ]]; then
    if [[ "$VERSION" =~ "magma" ]]; then
	echo "ERROR: no plugins list was supplied for $VERSION, that seems like a mistake."
	exit 1
    else
	PLUGLIST=""
    fi
else
    if [[ ! -f "$PLUGLIST" ]]; then
        echo "ERROR: could not find plugin list file."
	exit 1
    else
	echo "INFO: using mods from $PLUGLIST"
    fi
fi
set -u

### figure out how much memory Minecraft can use
TOTALMEM=$(free -m | awk '/Mem:/ { print $2 }')
if [ "$TOTALMEM" -lt "2048" ]; then
    echo "ERROR: Only detected ${TOTALMEM}M of RAM. Please use a server with at least 2048M."
    exit 1
elif [ "$TOTALMEM" -gt "$MAXRAM" ]; then
    MEMORY="$MAXRAM"
else
    MEMORY=$((TOTALMEM-512))
fi
echo "INFO: This system has ${TOTALMEM}M of RAM. Mincraft will use ${MEMORY}M"

### create group for servers to runas
if getent group minecraft > /dev/null ; then
    echo "INFO: minecraft group exists."
else
    set -e
    echo "WARN: minecraft group not found. Creating."
    sudo groupadd -r minecraft
    sudo usermod -a -G minecraft $(whoami)
fi

### create user for servers to runas
set +e
if id -u minecraft > /dev/null ; then
    echo "INFO: minecraft user exists."
else
    set -e
    echo "WARN: minecraft user not found. Creating."
    sudo useradd -r -m -g minecraft -s /bin/bash minecraft
fi

### make sure necessary ports are open
set +e
if sudo iptables -C INPUT -p tcp --dport 30000:31000 -j ACCEPT > /dev/null ; then
    echo "INFO: Firewall rule for ports 30000-31000 found, ports are open."
else
    set -e
    echo "WARN: Firewall rule not found. Opening up TCP ports 30000-31000 for Minecraft."
    sudo iptables -I INPUT -p tcp --dport 30000:31000 -j ACCEPT
fi

### create directory for server
set -e
if [ -d "/opt/minecraft/" ]; then
    echo "INFO: minecraft directory exists."
else
    echo "WARN: minecraft directory not found. Creating."
    sudo mkdir -p /opt/minecraft/
    sudo chmod 777 /opt/minecraft/
fi

### install Java versions
set +e
if [[ "$(update-alternatives --display java 2>&1)" =~ "java-8-openjdk" ]]; then
    echo "INFO: found Java 8 runtime."
else
    set -e
    echo "WARN: Java 8 runtime not found. Attempting to install."
    sudo apt-get -qq update
    sudo apt-get -qq -y install openjdk-8-jre-headless
fi
if [[ "$(update-alternatives --display java 2>&1)" =~ "java-17-openjdk" ]]; then
    echo "INFO: found Java 17 runtime."
else
    set -e
    echo "WARN: Java 17 runtime not found. Attempting to install."
    sudo apt-get -qq update
    sudo apt-get -qq -y install openjdk-17-jre-headless
fi

### pick correct Java version for selected Minecraft version and apply log4j workarounds
### https://www.minecraft.net/fr-fr/article/important-message--security-vulnerability-java-edition
if [[ "$(update-alternatives --display java 2>&1)" =~ "error: no alternatives for java" ]]; then
    echo "ERROR: java versions should have been installed but cant be found."
    exit 1
fi
if [ $(echo $VERSION | cut -d '-' -f 2 | cut -d '.' -f 2) -lt "17" ]; then
    JAVAV="$(update-alternatives --display java | grep -m 1 -o "/.*8.*/bin/java")"
    JAVAOPT="-Dlog4j.configurationFile=log4j2_112-116.xml"
elif  [ $(echo $VERSION | cut -d '-' -f 2 | cut -d '.' -f 2) -eq "17" ]; then
    JAVAV="$(update-alternatives --display java | grep -m 1 -o "/.*17.*/bin/java")"
    JAVAOPT="-Dlog4j2.formatMsgNoLookups=true"
else
    JAVAV="$(update-alternatives --display java | grep -m 1 -o "/.*17.*/bin/java")"
    JAVAOPT=""
fi
echo "INFO: Using java command: $JAVAV"
echo "INFO: Using additional java options: $JAVAOPT"

### install lighttpd to display MC server versions and modlists
set +e
if [ -x "$(command -v lighttpd)" ]; then
    set -e
    echo "INFO: found lighttpd."
else
    set -e
    echo "WARN: lighttpd not found. Attempting to install."
    sudo apt-get -qq update
    sudo apt-get -qq -y install lighttpd gridsite-clients
    sudo sed -i 's/server.port.*/server.port = 30000/' /etc/lighttpd/lighttpd.conf
fi
sudo systemctl restart lighttpd.service

### Install mcrcon
set +e
if [ -x "$(command -v mcrcon)" ]; then
    set -e
    echo "INFO: found mcrcon."
    if [[ $UPDATE == "TRUE" ]]; then
	echo "INFO: updating mcrcon."
	cd /opt/minecraft/tools/mcrcon/
	sudo -u minecraft git pull
	sudo -u minecraft make
	sudo make install
    fi
else
    set -e
    echo "WARN: mcrcon not found. Attempting to install."
    sudo -u minecraft mkdir -p /opt/minecraft/tools
    sudo apt-get -qq update
    sudo apt-get -qq -y install git build-essential
    cd /opt/minecraft/tools
    sudo -u minecraft git clone https://github.com/Tiiffi/mcrcon.git
    cd /opt/minecraft/tools/mcrcon
    sudo -u minecraft make
    sudo make install
fi

### Rebuild server listing in case it's gotten out-of-date
refresh_html

### make a directory for the new server instance
set +e
LAST=$(ls -d /opt/minecraft/server* | sed 's#/opt/minecraft/server##' | sort -n | tail -n 1)
set -e
if [[ "$LAST" == "" ]]; then
    NUM="1"
else
    NUM=$((LAST+1))
fi
DIR="/opt/minecraft/server${NUM}"
mkdir -p $DIR
echo "INFO: New server being installed to $DIR"

### download and install server
JAR="server.jar"
echo "INFO: downloading ${versions[$VERSION]}"
wget -q ${versions[$VERSION]} -P $DIR/

echo "INFO: downloading log4j XML even if it's not needed, because it's easier to always grab them."
wget -q "https://launcher.mojang.com/v1/objects/02937d122c86ce73319ef9975b58896fc1b491d1/log4j2_112-116.xml" -P $DIR/
wget -q "https://launcher.mojang.com/v1/objects/4bb89a97a66f350bc9f73b3ca8509632682aea2e/log4j2_17-111.xml" -P $DIR/

cd $DIR
echo $VERSION > $DIR/mc_version.txt
if [[ $VERSION =~ "fabric" ]]; then
    echo "INFO: Installing Fabric."
    eval $JAVAV -jar $(basename ${versions[$VERSION]}) server -downloadMinecraft -mcversion $(echo $VERSION | cut -f 2 -d '-')
    JAR="fabric-server-launch.jar"
elif [[ $VERSION =~ "forge" ]]; then
    echo "INFO: Installing Forge."
    echo "INFO: Logging installation status at $DIR/forge_installer.log"
    eval $JAVAV -jar $(basename ${versions[$VERSION]}) --installServer > $DIR/forge_installer.log
    JAR="$(basename ${versions[$VERSION]} | sed 's/-installer//')"
elif [[ $VERSION =~ "magma" ]]; then
    echo "INFO: Installing Magma."
    if [[ "$(basename ${versions[$VERSION]})" =~ "-installer" ]]; then
	echo "INFO: Logging installation status at $DIR/magma_installer.log"
	eval $JAVAV -jar $(basename ${versions[$VERSION]}) --installServer > $DIR/magma_installer.log
	JAR="$(basename ${versions[$VERSION]} | sed 's/-installer//' | sed 's/Magma-/forge-/')"
    else
	eval $JAVAV -jar $(basename ${versions[$VERSION]})
	JAR="$(basename ${versions[$VERSION]})"
    fi
elif [[ $VERSION =~ "vanilla" ]]; then
    echo "INFO: No additional setup required for vanilla."
else
    echo "ERROR: unrecognized version, how did we get here?"
    exit 1
fi
if [[ ! -f $DIR/$JAR ]]; then
    echo "ERROR: $DIR/$JAR not found after installation."
    exit 1
else
    echo "INFO: $DIR/$JAR will be started via a systemd service file."
fi

### download mods
if [[ "$MODLIST" != "" ]]; then
    mkdir $DIR/mods/
    cp $MODLIST $DIR/mods.txt
    echo "INFO: downloading mods"
    wget -q -i $MODLIST -P $DIR/mods/
fi

### download plugins
### Instructions for getting direct links from spiget.org
### https://www.spigotmc.org/threads/static-latest-download-links-for-plugins.161350/#post-1714547
if [[ "$PLUGLIST" != "" ]]; then
    mkdir $DIR/plugins/
    cp $PLUGLIST $DIR/plugins.txt
    echo "INFO: downloading plugins"
    while IFS="" read -r p || [ -n "$p" ]; do
	PNAME=$(echo $p | cut -f 1 -d " ")
	PNUM=$(echo $p | cut -f 2 -d " ")
	wget -q -O $DIR/plugins/$PNAME https://api.spiget.org/v2/resources/$PNUM/download
    done < $PLUGLIST
fi

### update server info webpage now that everything is installed
echo "INFO: Adding new server to /var/www/html/index.html"
add_server_html $DIR

### agree to EULA
echo "eula=true" > $DIR/eula.txt

### set a server op
if [[ $NAME == "Steve" || $UUID == "00000000-0000-0000-0000-000000000000" ]]; then
    echo "WARN: NO SERVER OP WAS DEFINED. Operators will need to use mcrcon to interact with server."
    echo "INFO: TO DEFINE A SERVER OP, edit the NAME and UUID variables at the beginning of this script."
    echo "INFO:     nano $0"
else
    echo "INFO: Making $NAME with UUID = $UUID the server op."
    cat <<EOF > $DIR/ops.json
[
  {
    "uuid": "$UUID",
    "name": "$NAME",
    "level": 4,
    "bypassesPlayerLimit": true
  }
]
EOF
fi

### create user whitelist
# TODO

### collect required minecraft server properties
SPORT=$((NUM+30000))
RPORT=$((NUM+26000))
QPORT=$((NUM+25000))
set +e
RPASS=$(cat /dev/urandom | tr -cd '[:alnum:]' | head -c 12)
set -e

### write server.properties file
echo "INFO: writing out $DIR/server.properties"
cat <<EOF > $DIR/server.properties
motd="Minecraft $VERSION at $HOSTIP:$SPORT - visit http://$HOSTIP:30000 for mods in use."
enable-rcon=true
rcon.password=$RPASS
query.port=$QPORT
rcon.port=$RPORT
server-port=$SPORT
EOF
if [ -f $EXTRAPROP ]; then
    echo "INFO: adding user supplied server.properties from $EXTRAPROP"
    cat $EXTRAPROP >> $DIR/server.properties
    cp $EXTRAPROP $DIR/extra.properties
fi
# TODO: if a whitelist was provided set "white-list=true" and "enforce-whitelist=true"

### create service file
echo "INFO: writing service file to /etc/systemd/system/minecraft${NUM}.service"
sudo tee /etc/systemd/system/minecraft${NUM}.service <<EOF > /dev/null
[Unit]
Description=Minecraft${NUM} Server
After=network.target

[Service]
User=minecraft
Nice=1
KillMode=none
SuccessExitStatus=0 1
ProtectHome=true
ProtectSystem=full
PrivateDevices=true
NoNewPrivileges=true
WorkingDirectory=/opt/minecraft/server${NUM}
ExecStart=$JAVAV -Xmx${MEMORY}M -Xms${MEMORY}M $JAVAOPT -jar $JAR nogui
ExecStop=/opt/minecraft/tools/mcrcon/mcrcon -H 127.0.0.1 -P $RPORT -p $RPASS stop

[Install]
WantedBy=multi-user.target
EOF

### setup daily backups
SERVERNAME=$(hostname)
SERVERNAME+=$(ip link | grep ether | awk '{print $2}' | awk -F  ":" '{print $4 $5 $6}')
echo "INFO: scheduling daily backup through /etc/cron.daily/mcbakup${NUM}"
mkdir -p /opt/minecraft/backups
sudo tee /etc/cron.daily/mcbakup${NUM} <<EOF > /dev/null
#!/bin/bash

function rcon {
  mcrcon -H 127.0.0.1 -P $RPORT -p $RPASS "\$1"
}

rcon "save-off"
rcon "save-all"
tar -cvpzf /opt/minecraft/backups/${SERVERNAME}_minecraft_server${NUM}-\$(date +%F_%R).tar.gz /opt/minecraft/server${NUM}
rcon "save-on"

## Delete older backups
find /opt/minecraft/backups/ -type f -mtime +7 -name '*.gz' -delete
EOF
sudo chmod +x /etc/cron.daily/mcbakup${NUM}

### Make sure server is set to install updates
if [[ "$(apt -qq list unattended-upgrades 2>/dev/null)" =~ "installed" ]]; then
    echo "INFO: unattended-upgrades package found, no action needed."
else
    echo "WARN: unattended-upgrades package not found, highly recommended to install it."
    echo "WARN:     sudo apt install unattended-upgrades"
fi

### Finalize installation
sudo chown -R minecraft.minecraft /opt/minecraft
sudo systemctl daemon-reload

### Print post-install directions
echo ""
echo "====== DONE INSTALLING $VERSION ====== "
echo "Info for all servers at http://$HOSTIP:30000"
echo ""
if [[ $AUTOSTART == "TRUE" ]]; then
    echo "Starting the new server."
    sudo systemctl enable minecraft${NUM}.service
    sudo systemctl start minecraft${NUM}.service
else
    echo "Run the following commands to enable and start the new server:"
    echo "    sudo systemctl enable minecraft${NUM}.service"
    echo "    sudo systemctl start minecraft${NUM}.service"
fi
echo "To monitor the new server run:"
echo "    journalctl -b -f -u minecraft${NUM}.service"
echo "If needed, save firewall rules:"
echo "    sudo iptables-save | sudo tee /etc/iptables/rules.v4"
if [ -f $DIR/ops.json ]; then
    echo "$NAME is an operator for this server. mcrcon can also be used to administer:"
else
    echo "No operator was set for this server. Use mcrcon to administer:"
fi
echo "    mcrcon -H 127.0.0.1 -P $RPORT -p $RPASS <COMMAND>"
echo "To remove this server, run:"
echo "    mc_server_setup.sh -d server${NUM}"
