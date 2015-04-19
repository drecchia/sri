#!/usr/bin/perl 

# Checa se a instancia anterior esta rodando
if ($ARGV[0] =~ /\-check/) {
	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$ENV{HOME}/.sri/pid");

	open(LATIME, "$ENV{HOME}/.sri/.mtime");
	$lmtime=<LATIME>;
	close(LATIME);
#	print "Comparando $lmtime com $mtime\n";
	if ($lmtime == $mtime) {
#		print "No update file, client needs reload\n";
		open(PIDF, "$ENV{HOME}/.sri/pid");
		        $pid=<PIDF>;
			close(PIDF);
			open(CHECK, "/proc/$pid/cmdline");
			     while (<CHECK>) {
			          $pidrunning='1' if ((/client.pl/) && (!/defunct/i));
			     }
			close(CHECK);
			
		goto RELOAD;
	} else {
		open(LATIME, ">$ENV{HOME}/.sri/.mtime");
		print LATIME $mtime;
		close(LATIME);
		die("Access time is up to date, Client is running\n");
	}

	#open(PIDF, "$ENV{HOME}/.sri/pid");
	#$pid=<PIDF>;
	#close(PIDF);
	#open(CHECK, "/proc/$pid/cmdline"); 
	#while (<CHECK>) {
#		$pidrunning='1' if ((/client.pl/) && (!/defunct/i));
#	}
#	close(CHECK);

#	die("Pid $pid is running\n") if ($pidrunning);

}

if ($ARGV[0] =~ /\-reload/) {
	RELOAD:
	open(PIDF, "$ENV{HOME}/.sri/pid");
        $pid=<PIDF>;
        close(PIDF);
	$killed=kill 9,$pid;
	die("Pid $pid killed, restarting\n") if ($pidrunning eq '1');
}



# client die on update, use the loop to reload
while (true) {

if ( -e "$ENV{HOME}/.sri/client.pl.new") {
        print "Instalando nova versao\n";
        unlink("$ENV{HOME}/.sri/client.pl.old") && print "Deletado oldest client\n" || print "cant delete oldest client version\n";
       
        unlink("$ENV{HOME}/.sri/config.old") && print "Deletado oldest config\n" || print "cant delete oldest config version\n";
        unlink("/tmp/sri_*.tgz") && print "Deletado tgz file\n" || print "Cant delete tgz file\n";

        rename("$ENV{HOME}/.sri/client.pl", "$ENV{HOME}/.sri/client.pl.old") && print "Renomeado client.pl\n"|| print "Cant rename client.pl to old\n";
        rename("$ENV{HOME}/.sri/config", "$ENV{HOME}/.sri/config.old") || print "Cant rename config to old\n";

        rename("$ENV{HOME}/.sri/client.pl.new", "$ENV{HOME}/.sri/client.pl") && print "Renomeado client.pl.new\n" || print "Cant rename client.pl\n";
        rename("$ENV{HOME}/.sri/config.new", "$ENV{HOME}/.sri/config") || print "Cant rename config\n";
}

# client die on update, use the loop to reload
	$tmp="$ENV{HOME}";
	$tmp=~s/\ /\\\ /g;
         system("$tmp/.sri/client.pl");
         print "novo loop em 10s\n";
        sleep("10");
}
