package CloudReady::CountTSql;

use strict;
use warnings;

use Erreurs;
use CloudReady::detection;
use CloudReady::config;
use CloudReady::Ident;

sub checkPatternSensitive($$) {
	my $reg = shift;
	my $code = shift;
	
	return () = ($$code =~ /$reg/gm);
}

sub checkCreateCredentials($$) {
	my $code = shift;
	my $HString = shift;
	my $nb_credentials = 0;

    if ($$code =~ /\bCREATE\s+CREDENTIAL\b/)
    {
        $nb_credentials++;
    }
    
	for my $stringId (keys %$HString) {
		if ($HString->{$stringId} =~ /^["'](?:\bCREATE\s+CREDENTIAL\b)/) {
			$nb_credentials++;
		}
	}

	return $nb_credentials;
}


sub CountTSql($$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_ ;
	my $ret = 0;
	
	my $code;
	my $HString;
	my $checkPattern = \&checkPatternSensitive;
	
	$code = \$vue->{'code'};
	$HString = $vue->{'HString'};
    
	if ((! defined $code ) || (!defined $$code)) {
		#$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
    
    # HL-390 21/12/17 [Unsupported SQL Server features] fn_my_permissions
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_fn_my_permissions(), $checkPattern->(qr/\bfn_my_permissions\b/, $code));
    # HL-391 28/12/17 [Unsupported SQL Server features] sp_addmessage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_sp_addmessage(), $checkPattern->(qr/\bsp_addmessage\b/, $code));
    # HL-392 28/12/17 [Unsupported SQL Server features] fn_get_sql, fn_virtualfilestats, fn_virtualservernodes
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_fn_get_sql(), $checkPattern->(qr/\bfn_get_sql\b/, $code));
	
	# Desactivated in accordance with issues HL-392 
	#CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_fn_virtualfilestats(), $checkPattern->(qr/\bfn_virtualfilestats\b/, $code));
	
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_fn_virtualservernodes(), $checkPattern->(qr/\bfn_virtualservernodes\b/, $code));
    # HL-393 28/12/17 [Unsupported SQL Server features] SEMANTICKEYPHRASETABLE (semantic search)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SEMANTICKEYPHRASETABLE(), $checkPattern->(qr/\bSEMANTICKEYPHRASETABLE\b/, $code));
    # HL-394 28/12/17 [Unsupported SQL Server features] OPENxxx (linked server)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_OPENQUERY(), $checkPattern->(qr/\bOPENQUERY\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_OPENROWSET(), $checkPattern->(qr/\bOPENROWSET\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_OPENDATASOURCE(), $checkPattern->(qr/\bOPENDATASOURCE\b/, $code));
    # HL-395 29/12/17 [Unsupported SQL Server features] USE statement
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_USE_statement(), $checkPattern->(qr/\bUSE\b/, $code));
    # HL-396 29/12/17 [Unsupported SQL Server features] CREATE CREDENTIAL
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_CreateCredential(), checkCreateCredentials($code, $HString));
    # HL-397 29/12/17 [Unsupported SQL Server features] ALTER DATABASE
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AlterDatabase(), $checkPattern->(qr/\bALTER\s+DATABASE\b/, $code));

	return $ret;
}

1;
