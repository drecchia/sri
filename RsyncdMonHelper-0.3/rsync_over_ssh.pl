#!/usr/bin/perl
# os indices de alteracao variam de 0.3 a 0.4%


system("clear");
do("funcoes");

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
$year+=1900;
$mon+=1;

#$mday='21';
$mday="[0-9]+" if ($ARGV[1]=~ /all/);

$lmon='Jul' if ($mon = '7');
$lmon='Aug' if ($mon = '8');

open(FILE, $ARGV[0]);
while (<FILE>) {
if ((defined $nextistime) && (/$lmon\ $mday\ /)) {
  print "\nBegin on: $_";
  $countbegin+=1;
  @line=split(/\ /);
  $timestart=&timeconvert2("$line[3]");
  $beginofone='1';
}
undef $soma if (defined $nextistime);

  print " \* " if ((/building/) && (defined $beginofone));
  if (/^sent/) {
    @line=split(/\ /);
    $line[1]=int($line[1]/1024) if ($line[1] > '1024');
    $soma+=$line[1];
    $soma2+=$line[1];
    $medida='Kb';
    if ($line[1] > '1024'){$medida='Mb';$line[1]=int($line[1]/1024);}
    print "$line[1]$medida" if (defined $beginofone);
  }

undef $nextistime;
if (/Starting/) {
  $nextistime='1';
}
if ((defined $nextistime) && ($lastline =~ /\:/) && ($lastline =~ /\ $mday\ /)) {
  undef $beginofone;
  print " \t\= $soma Kb\nEnd on:   $lastline";
  @line=split(/\ /, $lastline);
  $timeend=&timeconvert2($timestart-&timeconvert2("$line[3]"));
  print "Tempo usado: $timeend\n";
} elsif (($lastline !~ /\:/) && (defined $nextistime) && ($lastline =~ /\ $mday\ /)) {
  undef $beginofone;
  print " \t\= $soma Kb\nEnd on:   Finalizado por motivos obscuros\n";
}
$lastline="$_";
}
if ($lastline =~ /\:/) {
  print " \t\= $soma Kb\nEnd on:   $lastline";
  @line=split(/\ /, $lastline);
  $nowbk=&timeconvert2("$hour:$min:$sec");
  $timeend=&timeconvert2($timestart-&timeconvert2("$line[3]"));
# SE AINDA N TA NA HORA DO 1 BKP DO DIA
  if ($nowbk < $ARGV[2]) {
  $line[3]=$ARGV[2] if (defined $ARGV[2]);
  $nextbk=(&timeconvert2("02:00:00")+&timeconvert2("$line[3]"));
  $nextbk=&timeconvert2("$line[3]") if (defined $ARGV[2]);
  } else {
# SE JA PASSOU DA HORA DO 1 BKP DO DIA
  $nextbk=(&timeconvert2("02:00:00")+&timeconvert2("$ARGV[2]"));
  }
  $lastbk=&timeconvert2("$line[3]");
  print "Tempo usado: $timeend\n";
# BKP ATRASADO, MOSTRA NEXT BKP
  if ($nextbk > $nowbk) {
print "i lost one\n";
  $t=$nextbk-$nowbk;
  print "Prox bkup em: ".&timeconvert2($t)."\n";
  } 
  if ($line[3] < $nowbk) {
# BKP 
  $t=$nowbk-$lastbk;
  print "Prox bkup emm: -".&timeconvert2($t)."\n";
  }

  } else {
  print " \t\t\= $soma Kb\nStill runing\n";
}
close(FILE);

$soma2=int($soma2/$countbegin) if (($ARGV[1]=~ /all/) && ($countbegin > '0'));
print "Media consumo:$soma2"  if ($ARGV[1]=~ /all/);
