#!/usr/bin/perl
# by Delta Tecnologia - 24/12/2006
#
# cliente sera responsavel por elimirar os arquivos da ignore_list
################################################ VARIAVEIS ##############################################

do("$ENV{HOME}/.sri/config");
do("$ENV{HOME}/.sri/account");
$cygwin='no';

$client_logfile='log_client.txt';

$sleeptime='20';	# SECONDS BETWEEN MASTER QUERY
$defsleep=$sleeptime;
$badconnec='0';
$installpath="$ENV{HOME}/.sri";

################################################ BIBLIOTECAS ############################################

use IO::Socket;
use File::Find ();
use Archive::Tar;

#########################################################################################################

open(PIDF, ">$ENV{HOME}/.sri/pid");
print PIDF $$;
close(PIDF);

do {
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


sub lersocket() {
#	print "Lendo socket\n";
        while (<$sock>) {
                print "\<\- $_";
		return "$_";
                break;
        }
} # sub

sub tosocket() {
	print "\-\> $_[0]";
	print $sock "$_[0]";
} #sub

# variavel resposta, variavel a comparar, frase de morte
sub check() {
	print "\tChecking $_[0] with $_[1]\n";
#	print "\t${$_[0]} eq ${$_[1]}\n";
	if (${$_[0]} eq ${$_[1]}) {
		print "\t\tChecked $_[0] pass trought\n";
		return true;
	} else {
#		print "${$_[2]}";
		print "\t\tRejected\n";
		goto WAIT if (${$_[0]} !~ /http\:\/\//);
#		true;
	} 
	
} # sub
#########################################################################################
# flag q teoricamente permite as proximas tentativas, se passar o horario e nao fizer o bkp
#$no_complete_bkp_flag='0';
#########################################################################################

$my_handshake=&lersocket(); # le string inicial de conexao 
$die='not a valid handshake'."\n";
&check('my_handshake', 'global_handshake', 'die'); # valida string inicial

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
	&http_get("$tmp[2]", "/$tmp[3]/$tmp[4]");print "\n";
	print "Baixando atualizacoes.....\n";
	open(OUT, '>/tmp/sri.tgz');
	foreach (@urban) {
	        print OUT;
	}
	close(OUT);
	my $tar = Archive::Tar->new;
	$tar->read('/tmp/sri.tgz',1) || print "Cant read tgz file\n";
	$tar->extract_file( 'client.pl', "$installpath/client.pl.new" )  && print "Sucess extracted client.pl\n";
	$tar->extract_file( 'config', "$installpath/config.new" ) && print "Sucess extracted config\n";
	# Runme.pl eh responsavel pelo update 
	die("Run client again to update to reload the new version\n");
}


# PS: contador em modo cygwin... o programa sai, o contador se perde
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
# VALIDAR SE ESTAS PASTAS EXISTEM AINDA
# POR MOMENTO, nao validamos regexp ainda
@tmp=split(/\,/,$my_folder);
foreach $folder (@tmp) {
	$folder=~s/\^//g;
	chop $folder;
	if (! -e $folder) {
		# SEND THIS EVENT DO MASTER SERVER
		print "Warning: folder $folder nao esta mais presente entre nos\n";
	} elsif ((! -r $folder) && (-e $folder)) {
		print "Warning: folder $folder dont have corret permission setted\n";
	}
} # for
# SEND ENDOF FOLDER_CHEK STRING TO MASTER


&tosocket("$global_query_ignorelist");
$my_ignore=&lersocket(); # lista de ignore
# ELIMINAR O SINCRONISMO

&tosocket("$global_query_update"); # se deseja atualizar a tabela de bkp
$my_update=&lersocket();
if ($my_update eq $global_answer_ahead) {
	print "Building list of files\n";

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
	print "Update rejected\n";
}

WAIT:
#print "ill wait\n";
close($sock);
print "Sleeping\n";
sleep("$sleeptime") if ($cygwin eq 'no');
} while ((true) && ($cygwin eq 'no'));
