#!/usr/bin/perl
# eliminar duplicidade onde um global esta dentro de outro (.doc dentro do meus doc)

die("No enough arguments\n") if (!$ARGV[0]);
$client="$ARGV[0]";

#open(PERSONALLIST, "./bkplist/$client") if (-e "./bkplist/$client");
open(GLOBALLIST, "./bkplist/global_list") || die("Cant open ./bkplist/global_list file\n");
	@globallist=<GLOBALLIST>;
close(GLOBALLIST);

open(IGNORELIST, "./bkplist/ignore_list") || die("Cant open ./bkplist/ignore_list files\n");
	@ignorelist=<IGNORELIST>;
close(IGNORELIST);

open(FILELIST, "./filelist/$client") || die("Cant open ./filelist/$client file\n");

while (<FILELIST>) {
	foreach $glob (@globallist) {
		foreach $ig (@ignorelist) {
			if ((/$glob/i) && (!/$ig/i)) { $flag='1';}	
	
		}
		print "$_" if ($flag == '1');;
		$flag='0';
	}
}

close(FILELIST);
