#!/usr/bin/perl
# IMPLEMENTAR:
#		- programacao de desligamento/hibernate de clientes
#		- programacao de pre-execucao de aplicativo ( .bat por ex )
#		- validar arquivos/pastas de bkp dolado do cliente durante a comunicacao inicial
#
#	ATENCAO PARA TEMPO DE ALARM NO PRE-EXEC
#	ATENCAO PARA TEMPO DE ALARM NO RSYNC
#	APLICAR SUPORTE A VARIOS HORARIOS FIXOS
#
# no arquivo de log, so serao registrados infos ate a conexao com o sql, apos isso, somente no sql

################################# VARIAVEIS ##########################################
# diretorio que esta instalado a aplicacao
$installpath="/home/alaska/Devel/SRI";

# LOGIN MYSQL
$mysqllogin='root';
$mysqlpass='dammitb1ll';
$mysqlhost='127.0.0.1';
$logfile='log.txt';

################################# BIBLIOTECAS #############################################
use IO::Socket;
use DBI;

###########################################################################################
do("$installpath/config");
$alarm='5';

&report("Starting SRI Master.....");
&report("Conectado-se ao servidor mysql $mysqlhost com usuario $mysqllogin e senha $mysqlpass");
my $dbh = DBI->connect("DBI:mysql:database=SRI;host=$mysqlhost",
	                                "$mysqllogin", "$mysqlpass",
	                                {'RaiseError' => 1});


sub loadinarow() {
	my $tmp;my $sth;
	$sth = $dbh->prepare("$_[0]");
#	&report("Preparando $_[0]",0);
        $sth->execute();
        while (my $ref = $sth->fetchrow_hashref()) {
              $tmp.=$ref->{'REG_EXP'}.",";
         } #while
         $sth->finish();
	 chop $tmp;
	return $tmp;
	#print "Select failed at loadinarow: $@\n" if $@;	
}

sub gimmeonevalue() {
   my $lastid;undef @row;my $sth;
   eval {
   $sth = $dbh->prepare("$_[0] LIMIT 1");
   $sth->execute();
   while ( @row = $sth->fetchrow_array ) {
         $lastid="@row";
   }
   $sth->finish();
   };
   if ($@) {
	   print "Select failed at gimmeonevalue: $@\n";
	   ++$mysqlerror;
	   eval {
	   $dbh->disconnect;
	   $dbh = DBI->connect("DBI:mysql:database=SRI;host=$mysqlhost",
		                  "$mysqllogin", "$mysqlpass",
		                  {'RaiseError' => 1});
	   }; # eval
   	   print "Reconnect failed at gimmeonevalue: $@\n" if ($@);
   } else {
	  if ($mysqlerror > 0) {
		 &report("Conexao ao mysql perdida nas ultimas $mysqlerror conexoes", 10); 
		 $mysqlerror='0';
	  }
   }
   return $lastid;
}


sub report() {
   if (not defined $_[1]) {
  ($GLOBAL{sec},$GLOBAL{min},$GLOBAL{hour},$GLOBAL{mday},$GLOBAL{mon},$GLOBAL{year},$GLOBAL{wday},$GLOBAL{yday},$GLOBAL{isdst})=localtime(time);
  $GLOBAL{year}+=1900;
  $GLOBAL{mon}+=1;
  open(LOGFILE, ">>"."$installpath/$logfile") || die("Verifique permissoes de arquivo de log");
  print LOGFILE "[$$] \- $GLOBAL{mday}\-$GLOBAL{mon}\-$GLOBAL{year} $GLOBAL{hour}\:$GLOBAL{min}\:$GLOBAL{sec} \- $_[0]\n";
  close(LOGFILE);
  	} else {
  eval {$dbh->do("INSERT INTO LOG (CLIENTID,HORARIO,PID,IP,DESCRICAO,LEVEL) VALUES (\'$cl_id\',NOW(),\'$$\',\'$ip\',\'$_[0]\',\'$_[1]\')") };
  }
}

##########################################################################################

while (true) {
undef @tmp;
undef $login;
undef $tmp;
undef $bkpnow;

alarm 0;
my $sock = new IO::Socket::INET (
                                 LocalPort => '7072',
                                 Proto => 'tcp',
                                 Listen => 10,
                                 Reuse => 1,
				 #	 Timeout => 60,
				 #Blocking => 0,
                                 );


print "Aguardando conexao.....\n";
die "Could not create socket: $!\n" unless $sock;
$new_sock = $sock->accept();
$ip=$new_sock->peerhost;

###################################################################
sub timed_out() {
	    die "GOT TIRED OF WAITING";
}

sub lersocket() {
	local $SIG{ALRM} = sub { &time_out }; 
	eval {
        alarm 5;
        while (<$new_sock>) {
                print "\<\- $_";
                return "$_";
                break;
        }
	alarm 0;
	}; # eval
} # sub

sub tosocket() {
	print "\-\> $_[0]";
        print $new_sock "$_[0]";
} #sub

# variavel resposta, variavel a comparar, true=resposta para cliente, false=frase de morte
sub check() {
        print "\tChecking $_[0] with $_[1]\n";
#	print "............. ${$_[0]} with ${$_[1]}";
        if (${$_[0]} eq ${$_[1]}) {
                print "\t\tChecked $_[0] pass trought\n";
		&tosocket("${$_[2]}");
#		&report("Respondedo ao cliente com: ${$_[2]}",0);
        } else {
        #        print "$_[3]\n";
		$answer=$_[3];
		$answer="Tempo expirado na leitura de dados de entrada" if ($cl_version =~ /^$/);
		&tosocket("$answer\n");
		&report("$answer",4) if ($answer !~ /(not in time|never will be time|UPDATELIST)/i);
		goto WAIT if ($answer ne 'UPDATELIST');
        }

} # sub
###################################################


print "\t Got a client $ip, saying hello\n";

#AKI BLOKEAR BRUTE FORCE

&tosocket("$global_handshake");
$cl_id='0';
&report("Iniciando handshake com o cliente $ip",0);

$cl_username=&lersocket();
@tmp=split(/\ /, $cl_username);
$login=$tmp[2];
chop $login;
$cl_id=&gimmeonevalue("SELECT ID FROM CLIENTS WHERE LOGIN = \'$login\'");
$cl_full="$global_clientun $tmp[2]";
&check("cl_username", "cl_full", "global_answer_ahead", "Invalid username");

$cl_key=&lersocket();
$cl_full="$global_clientkey ".&gimmeonevalue("SELECT MD5(PASSWORD) FROM CLIENTS WHERE LOGIN = \'$login\'")."\n";
&check("cl_key", "cl_full", "global_answer_ahead", "Invalid key for $login");

$cl_version=&lersocket();
&check("cl_version", "global_versionst", "global_answer_ahead", "Disconnected, incompatible version, get at $global_newversion");

# LOG WITH WARNING SE MTAS CONEXOES INVALIDAS, podem acontecer tb pq os clients ocupam o sockt durante o update da lista
$cl_badconnection=&lersocket();
$tmp_level='0';
$tmp_level='10' if ($cl_badconnection =~ /\ [0-9]+[0-9][0-9]\ \*/); # 100 - 999
$tmp_level='8' if ($cl_badconnection =~ /\ [5-9][0-9]\ \*/); # 50 - 99 
$tmp_level='5' if ($cl_badconnection =~ /\ [1-4][0-9]\ \*/); # 10 - 49 
$tmp_level='3' if ($cl_badconnection =~ /\ [1-9]\ \*/); # 1 - 9
&report("Conexoes invalidas: $cl_badconnection",$tmp_level) if ($tmp_level > 0);

@tmp=split(/v/, $cl_version);
chop $tmp[1];
eval {$dbh->do("UPDATE CLIENTS SET CURR_IP=\'$ip\',VERSION=\'$tmp[1]\',LASTCONNECTION=NOW() WHERE LOGIN = \'$login\'") };

$my_alarm=&lersocket();
$tmp=&gimmeonevalue("SELECT BKP_TIME FROM CLIENTS WHERE LOGIN = \'$login\'");
if ($tmp =~ /\:/) {
	#print "Horario Fixo\n";
	($cl_hour,$cl_min)=split(/\:/, $tmp);
	$try_hora=&gimmeonevalue("SELECT IF(HOUR(NOW())=\'$cl_hour\','hour','none')");
	$try_min=&gimmeonevalue("SELECT MINUTE(NOW())-$cl_min");
     $last_bkp=&gimmeonevalue("SELECT (TIME_TO_SEC(NOW())-TIME_TO_SEC(LAST_BKP)) FROM CLIENTS WHERE LOGIN = \'$login\'");
     $next_bkp=&gimmeonevalue("SELECT LAST_BKP + INTERVAL 24 HOUR FROM CLIENTS WHERE LOGIN = \'$login\'");
     	# SE HORAPR=AGORA e MINPR-MINAGORA<10>0 e n fez bkp nos ultimos 15 minutos || OU n fez bkp a mais de 24h(ATENCAO fds)
	if ((($try_hora eq 'hour') && (($try_min < 10) && ($try_min >= 0)) && ($last_bkp > 900)) || (&gimmeonevalue("SELECT IF(\'$next_bkp\'<NOW(),'bkp','jump')") =~ /bkp/)) {
		print "Its time\n";
		eval { $dbh->do("UPDATE CLIENTS SET LAST_BKP=NOW() WHERE LOGIN = \'$login\'") };
		&report("Backup aceito: Horario Fixo",0);
		#$my_alarm='its time'."\n";
	} else {
		$my_alarm='not in time'."\n";
		&report("Backup rejeitado: rejeitado por horario (fixo)",0);
	}

} elsif ($tmp =~ /\*/) {
	$tmp=~s/\*\///g;
	#print "A cada $tmp horas\n";
	$next_bkp=&gimmeonevalue("SELECT LAST_BKP + INTERVAL $tmp HOUR FROM CLIENTS WHERE LOGIN = \'$login\'");
	$try_now=&gimmeonevalue("SELECT IF(\'$next_bkp\'<NOW(),'bkp','jump')");
	if ($try_now =~ /bkp/) {
		eval { $dbh->do("UPDATE CLIENTS SET LAST_BKP=NOW() WHERE LOGIN = \'$login\'") };
		#$my_alarm='its time'."\n";
		&report("Backup aceito: Horario dinamico",0);
	} else {
		$my_alarm='not in time'."\n";
		&report("Backup rejeitado: rejeitado por horario (dinamico)",0);
	}

} elsif ($tmp =~ /NEVER/) {
	$my_alarm="Never will be time"."\n";
	&report("Backup rejeitado: Horario Desativado",0);
}

# liberar o backup qdo o cliente esta atrasado com a requisicao em ate 1h
# cuidado para evitar duplicidade na liberacao se este monitoramento tiver sido reiniciado
&check("my_alarm", "global_query_alarm", "global_answer_ahead", "$my_alarm");

$cl_slave=&lersocket();
&check("cl_slave", "global_query_server", "server_serverslave", "No valid server query");
# PASSAR A PORTA TB

# RESULTADO DO TESTE DE PORTA FEITO PELO CLIENTE, REGISTRADO NO SQL LOGLEVEL
$cl_slave_state=&lersocket();
if ($cl_slave_state =~ /closed/) {
	&report("Teste de porta feito pelo cliente(slave): Rejeitado", 8);
	# CONFERIR SE AFIRMACAO CONFERE
} else {
	&report("Teste de porta feito pelo cliente(slave): Aceito", 0);
}

$cl_folder=&lersocket();
$cl_folder_type=&gimmeonevalue("SELECT BKP_GROUP FROM CLIENTS WHERE LOGIN = \'$login\'");
if ($cl_folder_type !~ /GLOBAL/) {
	$tmp=&loadinarow("SELECT REG_EXP FROM BACKUP_LIST WHERE CLIENTID = \'$cl_id\'")."\n";
} else {
	$tmp=&loadinarow("SELECT REG_EXP FROM BACKUP_LIST WHERE CLIENTID = \'$cl_id\' AND CLIENTID = \'9999\'")."\n";
}
&check("cl_folder", "global_query_folder", "tmp", "No valid folder query");

$cl_ignore=&lersocket();
$tmp=''."\n";
&check("cl_ignore", "global_query_ignorelist", "tmp", "No valid ignore_list query");

# A ATUALIZACAO DA LISTA SO SE DARA NA MESMA CONEXAO DO BKP, ISSO FIKA MEIO PESADO
# checar atualizacao de lista do arquivos do cliente, receptar e validar aqui ( antecao para cliente c/ particao )
$cl_update=&lersocket();
$tmp=&gimmeonevalue("SELECT UPDATE_FILE_LIST FROM CLIENTS WHERE LOGIN = \'$login\'");
$daysago=&gimmeonevalue("SELECT TO_DAYS(NOW())-TO_DAYS(LAST_FILE_LIST) FROM CLIENTS") if ($tmp !~ /NEVER/i);
$bkpnow='1' if ((($tmp =~ /WEEK/i) && ($daysago > 7)) || (($tmp =~ /MONTH/i) && ($daysago > 30)) || (($tmp =~ /DAY/i) && ($daysago > 1)));
if (defined $bkpnow) {
       &check("cl_update", "global_query_update", "global_answer_ahead", "Invalid update negociation");
	do {
		$tmp=&lersocket();
		eval { $dbh->do("INSERT INTO FILE_LIST (CLIENTID,INSERTDAY,FILE) VALUES (\'$cl_id\',NOW(),\'$tmp\')") };
	} while ($tmp !~ /^EOFLISTFILE/);
	eval {$dbh->do("UPDATE CLIENTS SET LAST_FILE_LIST =NOW() WHERE LOGIN = \'$login\'") };
} else {
       &check("cl_update", "global_query_update", "global_answer_refuse", "Invalid update negociation");
}

# TESTAR COMUNICACAO COM O SLAVE AKI

WAIT:
close($sock);
close($new_sock);
} # while true

