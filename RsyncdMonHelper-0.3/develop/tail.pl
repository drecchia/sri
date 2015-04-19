#!/usr/bin/perl

use File::Tail;
  $file=File::Tail->new("/home/alaska/usr/var/log/rsyncd.log");
  while (defined($line=$file->read)) {

undef $DATA;undef $HORA;undef $PID;undef $OBS;undef $IP;undef $FILE;undef $TRANSF;undef $OPERATION;

#2006/12/05 01:27:15 [12023] cygdrive/d/SUPORTE/Dev2000/DEV2000/GDES25/
#2006/12/04 07:01:01 [20641] rsyncd version 2.6.3 starting, listening on port 873
#2006/12/04 07:01:07 [20642] rsync to donattiautomacao/ from donattiautomacao@200-148-40-170.dsl.telesp.net.br (200.148.40.170)
#2006/12/04 09:01:10 [20642] tmp/
#2006/12/04 09:01:10 [20642] wrote 69 bytes  read 16710 bytes  total size 144393676
#2006/12/04 07:01:11 [20653] rsync to donattiautomacao/ from donattiautomacao@200-148-40-170.dsl.telesp.net.br (200.148.40.170)
#2006/12/04 09:01:11 [20653] wrote 69 bytes  read 819 bytes  total size 95664054
#2006/12/04 07:12:02 [22413] rsync to donattiiluminacao/ from donattiiluminacao@201-1-138-128.dsl.telesp.net.br (201.1.138.128)
#2006/12/04 09:12:04 [22413] mnt/hd/
#2006/12/04 09:12:04 [22413] mnt/hd/Samba/Base/Sistemas/Ilumina/


@tmp=split(/\ /, $line);

$DATA=$tmp[0];
$DATA=~s/\//\-/g;
$HORA=$tmp[1];
$PID=$tmp[2];
$PID=~s/\[//g;
$PID=~s/\]//g;

print "$line";
if ($line =~ /\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)/) {
#2006/12/04 09:12:06 [22413] 2006/12/04 09:12:06: host 201-1-138-128.dsl.telesp.net.br (201.1.138.128) recv mnt/hd/Samba/Base/Sistemas/Ilumina/CADEC.NTX (87040 bytes). Total 1236 bytes.

$OBS=$tmp[3];

$IP=$tmp[7];
$IP=~s/\(//g;
$IP=~s/\)//g;

$FILE=$tmp[9];
$SIZE=$tmp[10];
$TRANSF=$tmp[11];
$OPERATION='PARCIAL' if ($TRANSF < $SIZE);
$OPERATION='FULL' if ($TRANF >= $SIZE);

}

print "DATA: $DATA 
HORA: $HORA 
PID: $PID 
FILE: $FILE
SIZE:
OBS: $OBS\n";;


      print "$line" if ($line !~ /RULE/);

  }
