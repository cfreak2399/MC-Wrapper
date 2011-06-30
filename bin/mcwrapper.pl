#!/usr/bin/perl

use strict;
use IPC::Open2;
use Proc::Daemon;

my $java_default = `which java`;
chomp($java_default);
my $tar_default = `which tar`;
chomp $tar_default;
my $mcpid;
my $command;

die "MINECRAFT_HOME is not set." unless( exists $ENV{MINECRAFT_HOME} && -e $ENV{MINECRAFT_HOME});

my $backup_dir = $ENV{MINECRAFT_BACKUP_DIR} || $ENV{MINECRAFT_HOME} . "/backup";
my $world = $ENV{MINECRAFT_WORLD} || 'world';
my $java = $ENV{JAVA} || $java_default;
my $jar = $ENV{JAR} || 'minecraft_server.jar';
my $tar = $ENV{TAR} || $tar_default;
my $MOTD = $ENV{MINECRAFT_MOTD} || '';
my $pid_file = $ENV{MC_WRAPPER_PID} || '/var/run/mcwrapper.pid';
my $spid_file = $ENV{MC_SERVER_PID} || '/var/run/minecraft.pid';
my $shutdown_warning = $ENV{MINECRAFT_SHUTDOWN_WARN} || 5;

print "Setting MOTD to: $MOTD\n";
my $mc_user = $ENV{MINECRAFT_USER};
my $mc_user_id;
$mc_user_id = getpwnam($mc_user) if $mc_user;

my %opts = ();
$opts{work_dir} = $ENV{MINECRAFT_HOME};
$opts{setuid} = $mc_user_id if $mc_user_id;
my $daemon = Proc::Daemon->new(%opts);
my $pid = $daemon->Init;

unless( $pid ) {

	$mcpid = open2( *MCOUTPUT, *MCINPUT, "$java -Xmx1024M -Xms1024M -jar $jar nogui 2>&1");
	$| = 1;

# Setup control signals for the init script
	local $SIG{USR1} = sub {
		print "received backup signal\n";
		print MCINPUT "save-off\n";
		print MCINPUT "save-all\n";

		sleep 2; # wait for save to complete
		my @now = (localtime)[5,4,3];
		my $year = $now[0] + 1900;
		my $month = $now[1] + 1;
		my $day = $now[2];
		my $ts = time;
		my $bkfile = $backup_dir . "/" . sprintf("%s-%04d-%02d-%02d-%d.tar.gz",$world,$year,$month,$day,$ts );
		
		unless( system( $tar, 'czvf',$bkfile, $world ) == 0 ) {
			warn "Unable to create backup.";
		}
		print MCINPUT "save-on\n";
	};
	my $server_shutdown = sub {
		if( $shutdown_warning ) {
			print MCINPUT "say Server is shutting down in $shutdown_warning seconds.\n";
			sleep $shutdown_warning;
		}
		print MCINPUT "stop\n";
		
		sleep 2; # wait for clean shutdown
		kill "KILL", $mcpid; # make sure it's really dead
		close(MCOUTPUT);
		close(MCINPUT);
		exit;
	};


	local $SIG{INT} = $server_shutdown;
	local $SIG{TERM} = $server_shutdown;
	local $SIG{HUP} = $server_shutdown;

	my $direct_next_line_to;
	while( my $mc_said = <MCOUTPUT> ) {
		print $mc_said;
		if( $direct_next_line_to && $mc_said =~ /(Connected players:.+)$/) {
			print "telling $direct_next_line_to the list\n";
			print MCINPUT "tell $direct_next_line_to $1\n";
			$direct_next_line_to = '';
		}

		if( $MOTD && $mc_said =~ /\[INFO\]\s([^\[]+)\[\/[0-9\.:]+\]\slogged in/ ) {
			my $player = $1;
			#$player =~ s/\s$//;
			print "Detected log-in: $player\n";
			print MCINPUT "tell $player $MOTD\n";
		}

		if( $mc_said =~ /\[INFO\]\s([^\s]+) tried command: list/ ) {
			print "Detected list attempt\n";
			print MCINPUT "list\n";
			$direct_next_line_to = $1;
		}
	}
}
else {
	open(PIDFILE,">$pid_file") or warn "Couldn't open $pid_file: $!\n";
	print PIDFILE $pid;
	close(PIDFILE);
}
