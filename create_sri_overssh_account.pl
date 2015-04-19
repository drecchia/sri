#!/usr/bin/perl

open(INFO, 'remote-script');
while (<INFO>) {
$login=$_ if (/^U\:/);
push(@let, $_) if (/^F\:/);
}
close(INFO);

chop $login;
@tmp=split(/\:/, $login);
$pass=`echo -n $tmp[1]|md5sum|cut -d\- -f1`;
chop $pass;
print "Definindo senha como: $pass\n";
print "Adicionando login: $tmp[1]\n";
`useradd -m -d /mnt/sata/SRI/Rsyncssh/sri-$tmp[1] -p $pass sri-$tmp[1]`; 
`mkdir /mnt/sata/SRI/Rsyncssh/sri-$tmp[1]/.ssh`;
`cat identity.pub > /mnt/sata/SRI/Rsyncssh/sri-$tmp[1]/.ssh/authorized_keys`;
`rm identity.pub`;
`chown -R sri-$tmp[1] /mnt/sata/SRI/Rsyncssh/sri-$tmp[1]/.ssh`;

foreach (@let) {
chop;
@tmp2=split(/\:/, $_);
`mkdir /mnt/sata/SRI/Rsyncssh/sri-$tmp[1]/$tmp2[1]`;
`chown sri-$tmp[1] /mnt/sata/SRI/Rsyncssh/sri-$tmp[1]/$tmp2[1]`;
}


