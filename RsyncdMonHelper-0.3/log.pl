#!/usr/bin/perl

#use strict;

# checar somente os de hj 
# qdo ainda esta rodando, tempo estimado fica negativo e loko
# DURACAO DO BACKUP: 3/4 do tempo eh conexao, e o resto eh disco

#minuto de inicio de cada backup
#$rmh{counter}{cr}{timer}='01';
#$rmh{counter}{eiserver}{timer}='12';
#$rmh{counter}{entidadejovem}{timer}='53';
#$rmh{counter}{donattiautomacao}{timer}='31';
#$rmh{counter}{donattiiluminacao}{timer}='06';
#$rmh{counter}{donattihidraulico}{timer}='38';

my $logfile;
my %rmh;
my $total;
my $read;
my $time;
$total='0';

$logfile='/home/alaska/usr/var/log/rsyncd.log';

############################### SUBS ################################
do("funcoes");
####################################################################

open(LOG, $logfile);
while (<LOG>) {
my @line;my @bug;
####2005/03/09 15:06:01 [27204] max connections (3) reached

#2005/03/01 08:06:02 [5987] rsync to donattiiluminacao/ from donattiiluminacao@201-1-142-238.dsl.telesp.net.br (201.1.142.238)
# BLINK IN THIS CASE
###2005/02/21 08:06:02 [8248] auth failed on module donattiiluminacao from 201-1-139-127.dsl.telesp.net.br (201.1.139.127)
	@line=split(" ", $_);
	$line[2]=~s/\[//g;
	$line[2]=~s/\]//g;
	if (/rsync\ to/) {
		$total=$total+1;
		chop $line[8];
		$line[5]=~s/\///g;
		$rmh{$line[2]}{nomeb}="$line[5]";
		$rmh{$line[2]}{timestart}="$line[1]";
		$rmh{$line[2]}{from}="$line[8]";
		$rmh{$line[2]}{from}=~s/\(//g;
		$rmh{counter}{$line[5]}='0' if (not defined $rmh{counter}{$line[5]});
		$rmh{pids}{$line[5]}='' if (not defined $rmh{pids}{$line[5]});
#		print "ANT $line[5]: $rmh{counter}{$line[5]}\n";
		$rmh{counter}{$line[5]}=$rmh{counter}{$line[5]}+1;
#		print "DEP $line[5]: $rmh{counter}{$line[5]}\n";
		$rmh{pids}{$line[5]}="$rmh{pids}{$line[5]}"."$line[2] ";
	}
#2005/03/01 11:06:04 [5987] wrote 69 bytes  read 18676 bytes  total size 111089708
#2005/03/03 04:14:18 [15314] rsync error: timeout in data send/receive (code 30) at io.c(153)
if ((/\]\ wrote\ /) || (/\]\ rsync\ error\:\ timeout\ in/))  {
	# lets correct the time bug in rsyncd log
	@bug=split(/\:/, $line[1]);
	$rmh{$line[2]}{timeend}=($bug[0]-3)."\:$bug[1]\:$bug[2]";
	$rmh{$line[2]}{size}=int($line[7]/1024) if ($line[7] =~ /[0-9]/);	
	$rmh{size}{$rmh{$line[2]}{nomeb}}='0' if (not defined $rmh{size}{$rmh{$line[2]}{nomeb}});
	$rmh{size}{$rmh{$line[2]}{nomeb}}=$rmh{size}{$rmh{$line[2]}{nomeb}}+$rmh{$line[2]}{size};
	# bug - a little reconect after a backup, was incrisin pids
# Not bugged, the second conection is other dir to backup
#	if ((($line[4] == '69') && ($line[7] == '807')) || ($rmh{$line[2]}{timeend} =~ /$rmh{$line[2]}{timestart}/)) {
#		$rmh{counter}{$rmh{$line[2]}{nomeb}}=$rmh{counter}{$rmh{$line[2]}{nomeb}}-1;
#		$total=$total-1;
#		undef $rmh{$line[2]};
#	}
}
} # while
close(LOG);

print "Total: $total\n";
foreach (keys %{$rmh{counter}}) {
my @pids;my $pids;my $tmp;
	$time='0';
	print "Contei: $rmh{counter}{$_} para $_\n";
	@pids=split(/\ /, $rmh{pids}{$_});
	print "        ";
	foreach $pids (@pids) {
		if (defined $rmh{$pids}) {
		print "$pids " if (defined $rmh{$pids});
		$time=$time+&timeconvert("$rmh{$pids}{timestart}", "$rmh{$pids}{timeend}");
		}
	}
	print "\n";
	$rmh{size}{$_}='0' if ( not defined $rmh{size}{$_});
	print "        Total bandwidth: $rmh{size}{$_} Kbytes\n";
	print "        Total time: ".&timeconvert2($time)."\n";
	$tmp=&timeconvert2($time/$rmh{counter}{$_});
	print "        Tempo medio: ".&timeconvert2($tmp)."\n";
}

print "\nWhat pid you wanna know?\n";
$read=<STDIN>;chop $read;
$read='' if (not defined $read);
foreach (keys %{$rmh{$read}}) {
	print "$_\: $rmh{$read}{$_}\n";
}
print "Backup is still runing\n" if ( not defined $rmh{$read}{timeend});

