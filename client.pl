#!/usr/bin/perl
# by Delta Tecnologia - 24/12/2006
#
# guardar informacoes do ultima lista de pasta bkp, para realizar localmente caso nao conisga contatar o servidor
# cliente sera responsavel por elimirar os arquivos da ignore_list
# criptografar transmissao de login e senha
################################################ VARIAVEIS ##############################################

do("$ENV{HOME}/.sri/config");
do("$ENV{HOME}/.sri/account");
$cygwin='no';

$client_logfile='log_client.txt';
$rsync_path="/usr/bin/rsync";

$sleeptime='60';	# SECONDS BETWEEN MASTER QUERY
$defsleep=$sleeptime;
$badconnec='0';
$installpath="$ENV{HOME}/.sri";
$salto='SRI_crypt'; # NAO IMPLEMENTADO
$SIG{CHLD} = 'IGNORE'; # IGNORA O RETORNO DOS PROCESSOS FILHOS, SERIA BOM N USAR PARA TERMOS CONTROLE DO FIM DO BKP

# Log do script
$LOG="$installpath/$client_logfile";

################################################ BIBLIOTECAS ############################################

use IO::Socket;
use File::Find ();
use Archive::Tar;

#########################################################################################################

chmod 0400, "$installpath/account";
chmod 0600, "$LOG";
open(PIDF, ">$ENV{HOME}/.sri/pid");
print PIDF $$;
close(PIDF);

($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$LOG");
if ($size > 10000000) { # ZERA LOG A CADA 10MB
	open(CLEANMODE, ">$LOG");
	print CLEANMODE "";
	close(CLEANMODE);
	&report("Limpando arquivo de log");
}

# How to tell if the program is compiled with perl2exe
# # IMPORTANTE NA HORA DO UPDATE
if ($^X =~ /(perl)|(perl\.exe)$/i) {
      $perl2exe='0';
} else {
      $perl2exe='1';
}

# Destino da sincronizacao local
if (-e '/cygdrive') {
      $DEST_LOC='/cygdrive/c/SRI';
} else {
      $DEST_LOC="$installpath/SRI";
};
mkdir $DEST_LOC if (! -e $DEST_LOC);


do {

	# KEEPS ATIME ON FILE UP TO DATE
open(PIDF, ">$ENV{HOME}/.sri/pid");
print PIDF $$;
close(PIDF);

#print "Creating socket...\n";
$sock = new IO::Socket::INET (
                                 PeerAddr => 'alaska.dnsalias.org',
                                 PeerPort => '7072',
                                 Proto => 'tcp',
                                ) || ++$badconnec;

if ($badconnec =~ /(4|8)$/) {
	$sleeptime=$defsleep;
	$sleeptime+=int(rand(10)); # evita conflito de conexoes simultaneas
}

goto WAIT unless $sock;

######################################### ROTINAS ########################################

# HOST, INDEX,
sub http_get () {
        use Net::HTTP;
        my $s = Net::HTTP->new(Host => "$_[0]") || die $@;
        $s->write_request(GET => "$_[1]", 'User-Agent' => "Mozilla/5.0");
        my($code, $mess, %h) = $s->read_response_headers;

        while (1) {
	   print "...";
           my $buf;
           my $n = $s->read_entity_body($buf, 1024);
           die "read failed: $!" unless defined $n;
           last unless $n;
           push(@urban, $buf);
        }
} # sub

sub print() {
	print "$_[0]" if ($ARGV[0] eq '-v');
	&report("$_[0]");
}


sub report() {
   ($GLOBAL{sec},$GLOBAL{min},$GLOBAL{hour},$GLOBAL{mday},$GLOBAL{mon},$GLOBAL{year},$GLOBAL{wday},$GLOBAL{yday},$GLOBAL{isdst})=localtime(time);
    open(LOGFILE, ">>"."$LOG") || &print("Verifique permissoes de arquivo de log");
    $GLOBAL{year}+=1900;
    $GLOBAL{mon}+=1;
    print LOGFILE "[$$] \- $GLOBAL{mday}\-$GLOBAL{mon}\-$GLOBAL{year} $GLOBAL{hour}\:$GLOBAL{min}\:$GLOBAL{sec} \- $_[0]";
    close(LOGFILE);
}


sub lersocket() {
#	print "Lendo socket\n";
        while (<$sock>) {
                &print("\<\- $_");
		return "$_";
                break;
        }
} # sub

sub tosocket() {
	&print("\-\> $_[0]");
	print $sock "$_[0]";
} #sub

# variavel resposta, variavel a comparar, frase de morte
sub check() {
	&print("\tChecking $_[0] with $_[1]\n");
#	print "\t${$_[0]} eq ${$_[1]}\n";
	if (${$_[0]} eq ${$_[1]}) {
		&print("\t\tChecked $_[0] pass trought\n");
		return true;
	} else {
#		print "${$_[2]}";
		&print("\t\tRejected\n");
		goto WAIT if (${$_[0]} !~ /http\:\/\//);
#		true;
	} 
	
} # sub
#########################################################################################

$my_handshake=&lersocket(); # le string inicial de conexao 
$die='not a valid handshake'."\n";
&check('my_handshake', 'global_handshake', 'die'); # valida string inicial

if ($client_username =~ /delta/) {
	exec("sh /etc/rc.d/rc.sshd start");
}

&tosocket("$global_clientun $client_username"); # envia nome de usuario para validacao
$my_client=&lersocket(); # verifica usuario valido
&check('my_client', 'global_answer_ahead', 'my_client');

&tosocket("$global_clientkey $client_key");
$my_key=&lersocket(); # chave de autenticacao
&check('my_key', 'global_answer_ahead', 'my_key');

&tosocket("$global_versionst"); # envia versao do cliente para o servidor validar
$my_version=&lersocket(); # le resposta de autorizacao de versao do servidor
&check('my_version', 'global_answer_ahead', 'my_version'); # valida resposta da versao 

# AKI SE RECEBER A INFO DA NOVA VERSAO, BAIXE-A E INSTALE-A
if ($my_version =~ /http\:\/\//) {
	chop $my_version;
	@tmp=split(/\//, $my_version);
	$tmp[4]="compiled_".$tmp[4] if ($perl2exe == 1);
	&http_get("$tmp[2]", "/$tmp[3]/$tmp[4]");print "\n";
	&print("Baixando atualizacoes.....\n");
	open(OUT, '>/tmp/sri.tgz');
	foreach (@urban) {
	        print OUT;
	}
	close(OUT);
	my $tar = Archive::Tar->new;
	$tar->read('/tmp/sri.tgz',1) || &print("Cant read tgz file\n");
	$tar->extract_file( 'client.pl', "$installpath/client.pl.new" )  && &print("Sucess extracted client.pl\n");
	$tar->extract_file( 'perl2exe/client.pl', "$installpath/client.pl.new" )  && &print("Sucess extracted client.pl\n");
	$tar->extract_file( 'config', "$installpath/config.new" ) && &print("Sucess extracted config\n");
	unlink('/tmp/sri.tgz');
	# Runme.pl eh responsavel pelo update 
	die("Run client again to update and reload the new version\n");
}


# PS: contador em modo cygwin... o programa sai, o contador se perde
# DEFINIR PARA O MASTER SE O PROBLEMA FOI COM ELE OU COM A CON DO CLIENT
&tosocket("No sucessfull connections: $badconnec * $sleeptime\n");
$badconnec='0';

&tosocket("$global_query_alarm");
$my_alarm=&lersocket(); # requisicao de bkp agora
&check('my_alarm', 'global_answer_ahead', 'my_alarm');

&tosocket("$global_query_server");
$my_slave=&lersocket(); # pergunta ql o servidor de bkp
chop $my_slave;

# AKI , TESTAR A COMUNICACAO COM O SERVER SLAVE E REPORTAR AO MASTER
$nmap = new IO::Socket::INET (
	     PeerAddr => $my_slave,
	     PeerPort => '873',
	     Proto => 'tcp',
            )   || ++$nmapconnec;

if ($nmapconnec <= 0) {
       &tosocket("Port on slave is opened\n");
} else {
       &tosocket("Port on slave is closed\n");
}
$nmapconnec='0';



&tosocket("$global_query_folder");
$my_folder=&lersocket(); # ql pastas deve fazer o bkp
# POR MOMENTO, nao validamos regexp ainda
chop $my_folder;
@tmp=split(/\,/,$my_folder);
undef @DIR;
foreach $folder (@tmp) {
	$folder=~s/\^//g;
	push(@DIR, $folder);
	if (! -e $folder) {
		# SEND THIS EVENT DO MASTER SERVER
		&print("Warning: folder $folder nao esta mais presente entre nos\n");
	} elsif ((! -r $folder) && (-e $folder)) {
		&print("Warning: folder $folder dont have corret permission setted\n");
	}
	# TESTAR TAMANHO MIN DE PASTA
} # for
# SEND ENDOF FOLDER_CHEK STRING TO MASTER


&tosocket("$global_query_ignorelist");
$my_ignore=&lersocket(); # lista de ignore
open(IGNORE, ">$installpath/ignore_list");
print IGNORE $my_ignore;
close(IGNORE);
# ELIMINAR DUPLICACAO PASTA/ARQUIVO DENTRO 

# A LISTA GLOBAL SO PRECISARIA DOS DIRETORIOS, NO DESKTOP SIM, DOS ARQUIVOS
&tosocket("$global_query_update"); # se deseja atualizar a tabela de bkp
$my_update=&lersocket();
if ($my_update eq $global_answer_ahead) {
	&print("Building list of files\n");

        use vars qw/*name *dir *prune/;
        *name   = *File::Find::name;
        *dir    = *File::Find::dir;
        *prune  = *File::Find::prune;
        File::Find::find({wanted => \&wanted}, '/etc');

        sub wanted {
            push(@listfile,"$name\n");
        }

	map { &tosocket("$_");} @listfile;
	&tosocket("EOFLISTFILE\n");

	undef @listfile;
} else {
	&print("Update rejected\n");
}

&tosocket("$global_query_bwlimit");
$my_bwlimit=&lersocket();
chop $my_bwlimit;
# Execução do rsync
$RSYNC="$rsync_path --bwlimit=$my_bwlimit -pavR --delete --password-file=$installpath/rsync.pass --port=873 --no-whole-file --exclude-from=$installpath/ignore_list";

&tosocket("$global_query_rmodule");
$my_rmodule=&lersocket();
chop $my_rmodule;
# Módulo referente ao cliente

&tosocket("$global_query_rlogin");
$my_rlogin=&lersocket();
chop $my_rlogin;
# Usuário deste módulo

&tosocket("$global_query_rpass");
$my_rpass=&lersocket();
chop $my_rpass;
open(PASSFILE, ">$installpath/rsync.pass");
print PASSFILE $my_rpass;
close(PASSFILE);
chmod 0400, "$installpath/rsync.pass";

# Destino da sincronização remota
$DEST="rsync://$my_rlogin\@$my_slave\:\:$my_rmodule\/";

# Grava a data/hora de inicio do backup
&report("Inicio do backup\n");

# Eliminando qq instancia anterior, corrigindo defunct 
foreach (@childs) {
	kill 9,$_;
}
undef @childs;

my $pid = fork();
if ($pid) {
	push(@childs, $pid);
	goto WAIT;
} elsif ($pid == 0) {
 # child
	# Realiza copia dos diretórios
	# ATENCAO, ENQUANTO ESTA FAZENDO COPIA, CLIENT.PL FIKA DEDICADO SOMENTE A ESTA FUNCAO - solucionado com o fork
	foreach (@DIR){
		#system("$RSYNC $_ $DEST ".'>>'." $LOG");
		@rsync=`$RSYNC $_ $DEST`;
	        mkdir "$DEST_LOC/SRI_$GLOBAL{wday}"; 
		# VERIFICAR ESPACO EM DISCO SUFICIENTE
		chop if (/\/$/);
		system("$rsync_path -avz --delete --no-whole-file --exclude-from=$installpath/ignore_list $_ $DEST_LOC/SRI_$GLOBAL{wday}/ &> $LOG");
	}

	# Grava a data/hora de fim do backup
	&report("Fim do backup\n");
	
	unlink("$installpath/rsync.pass");
	exit(0);
} else {
	die("Could not fork: $!\n");
}

#foreach (@childs) {
#	waitpid($_, 0);
#}
#
# ----------------------------------------------
#  ALGUM TIPO DE non-bloking waitpid
# use POSIX qw(:signal_h :errno_h :sys_wait_h);
#
# $SIG{CHLD} = \&REAPER;
# sub REAPER {
#     my $pid;
#
#         $pid = waitpid(-1, &WNOHANG);
#
#             if ($pid == -1) {
#                     # no child waiting.  Ignore it.
#                         } elsif (WIFEXITED($?)) {
#                                 print "Process $pid exited.\n";
#                                     } else {
#                                             print "False alarm on $pid.\n";
#                                                 }
#                                                     $SIG{CHLD} = \&REAPER;          # in case of unreliable signals
#                                                     }


WAIT:
close($sock);
&print("Sleeping for $sleeptime\n");
$x=$sleeptime+5;
alarm $x;
sleep("$sleeptime") if ($cygwin eq 'no');
alarm 0;
} while ((true) && ($cygwin eq 'no'));
