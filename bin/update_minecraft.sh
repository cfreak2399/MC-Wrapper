if [ $MINECRAFT_HOME != "" ]; then
	cd $MINECRAFT_HOME
fi

if [ -e minecraft_server.jar ]; then
	mv minecraft_server.jar minecraft_server.jar.bak
fi

wget http://minecraft.net/download/minecraft_server.jar
