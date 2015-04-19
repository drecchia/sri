#!/usr/bin/perl
# by Danilo Trani Recchia - 21/06/05 - inicio projeto
#			  - 17/07/05 - ajustes
# Sistema de monitoracao do projeto SRI

use Term::ANSIScreen qw/:constants :color :cursor :screen :keyboard/;
use Term::ANSIMenu;

#Begin on: Fri Jun 10 20:00:00  2005
# * 29Kb * 2Kb   = 31 Kb
#End on:   Finalizado por motivos obscuros
#

my $dirbkp;
my %cliente;
my $instancias;
my @content;
my $count;
my $countint;
my $tempousado;
my $wait;

do("funcoes");
do("clientes");
$dirbkp="/mnt/IDE-40Gb-ext3/Rsyncssh";

# checa se o servidor rsync esta rodando nesta makina
sub ifrunning () {
my $cmdline;my @proc;my $myproc;
opendir(PROC, "/proc");
@proc=grep { /^[0-9]/} readdir(PROC);
closedir(PROC);
$instancias='0';
foreach $myproc (@proc) { 
	$cmdline='0';
	open(CMD, "/proc/$myproc/cmdline");
	$cmdline=<CMD>;
	close(CMD);
	if (defined $cmdline){ 
	return 1 if (($cmdline =~ /rsyncd\.conf/i) && (++$instancias) && ($cmdline !~ /gnome\-terminal/));
	}
}
}


sub header() { 
if ($_[0] !~ /update/) {
cls;
locate 0,0;
clline;
print colored ['bold white'], "                              -=  Rsync Mon Helper - v1.0 =-           ";
}
locate 2,0;
if (&ifrunning()) { print "Server is UP: $instancias"; }else { print colored ['bold red'],"Server is DOWN";} 
locate 2,70;
print localtime(time)."\n";
if ($_[0] !~ /update/) {
locate 3,0;
color 'blue on white';
print "    Cliente    ";
color 'white on black';print " ";
color 'blue on white';
print "     Backup     ";
color 'white on black';print " ";
color 'blue on white';
print "   Next   ";
color 'white on black';print " ";
color 'blue on white';
print "   Size   ";
color 'white on black';print " ";
color 'blue on white';
print " T ";
color 'white on black';print " ";
color 'blue on white';
print "   Bkp Int    ";
color 'white on black';print " ";
color 'blue on white';
print " Med Tran ";
color 'white on black';print " ";
color 'blue on white';
print " DECORRIDO ";
color 'white on black';print "\n";
}
} # end sub

# os argumentos permitem atualizar somente os campos necessarios ou todo cabecalho
&header("x");

# le os nomes/diretorios dos clientes
opendir(DIR, $dirbkp);
@content=grep {!/(\.|keys)/} readdir(DIR);
closedir(DIR);

while (not defined $wait) {
my @valrc;
$countclient='0';
@valrc=`./log.pl`;
foreach $orrs (@valrc) {
#Contei: 3 para eiserver
#        22417 6599 26919
#        Total bandwidth: 45252 Kbytes
#        Total time: 1:6:55
#        Tempo medio: 0:22:18
  if ($orrs =~ /^Contei/) {
	$count='';
	$countclient+=2;
	@line=split(/\ /, $orrs);
	$count=$line[1];
	chop $line[3];
	locate 2+$countclient,0;
	print "$line[3] ";
	# BKP
        locate 2+$countclient,19;
        foreach (1..$count) {
                color 'black on blue';print " ";color 'white on black';print " ";
        }
        while ($count < $cliente{$line[3]}{nbkp}) {
                $count+=1;
                color 'black on red';print " ";color 'white on black';print " ";
        }
	        # SINCRONIA DE HORARIO
        locate 2+$countclient,57;
        color 'black on green';print " ";color 'white on black';


  }

}
$count='';
print "\n\n";
foreach $name (@content) {
$tempousado='';
my @val;my @valmc;
@val=`./rsync_over_ssh.pl $dirbkp/$name/logs/rsync.log x $cliente{$name}{'starttime'}`;
@valmc=`./rsync_over_ssh.pl $dirbkp/$name/logs/rsync.log all`;
$countclient+=2;
print "$name ";
$count='0';$countint='0';
	foreach $val (@val) {
		if ($val =~ /Tempo\ usado/) {
			@tempo=split(/\:/, $val, 2);
			$tempousado=$tempo[1];
		}
		if ($val =~ /Begin/){
			$count+=1;
		}
		if ($val =~ /Prox\ bkup\ em\:/){
			@next=split(/\ /, $val);
			$next=$next[3];	
			chop $next;
		}
		if ($val =~ /\*/) {
			@line=split(//, $val);
			$countint='0';
			foreach $line (@line) {
			$countint+=1 if ($line =~ /\*/);
			}
		}
	}
	# BKP
	locate 2+$countclient,19;
	foreach (1..$count) {
		color 'black on blue';print " ";color 'white on black';print " ";
	}
	while ($count < $cliente{$name}{nbkp}) {
		$count+=1;
                color 'black on red';print " ";color 'white on black';print " ";
	}

	# SINCRONIA DE HORARIO
	locate 2+$countclient,57;
	color 'black on green';print " ";color 'white on black';	

	# PROX HORARIO
	locate 2+$countclient,35;
	if (defined $next) {
	if ($next =~ /\-/) {
	print colored ['bold red'], "$next  ";
	} else {
	print "$next  ";
	}
	}

	# BKP INTERNO 
	locate 2+$countclient,62;
	foreach (01..$countint) {
	color 'black on blue';print " ";color 'white on black';print " ";
	}
	while ($countint < $cliente{"$name"}{'nbkpint'}) {
		$countint+=1;
		color 'black on red';print " ";color 'white on black';print " ";
	}
	
	# VAL MEDIA CONSUMO
	locate 2+$countclient,76;
	@valmc=split(/\:/, $valmc[$#valmc]);
	print "$valmc[1]/0000";

	# DECORRIDO
	locate 2+$countclient,87;
	chop $tempousado;
	print "$tempousado";

print "\n\n";
}
sleep 10;
#$varwait=<STDIN>;
&header('update');
}


print color 'reset';
