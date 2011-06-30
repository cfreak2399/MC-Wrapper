# This program is free software and is provided to you with NO WARRANTY.
# You are free to modify and distribute this program under the terms of
# the GNU GPL v2.1. See the LICENSE file or visit 
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt for more details


if [ $MINECRAFT_HOME != "" ]; then
	cd $MINECRAFT_HOME
fi

if [ -e minecraft_server.jar ]; then
	mv minecraft_server.jar minecraft_server.jar.bak
fi

wget http://minecraft.net/download/minecraft_server.jar
