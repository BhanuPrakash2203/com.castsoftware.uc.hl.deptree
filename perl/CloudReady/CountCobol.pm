package CloudReady::CountCobol;

use strict;
use warnings;

use Erreurs;
use CloudReady::detection;
use CloudReady::config;
use CloudReady::Ident;
use CloudReady::lib::HardCodedIP;
use CloudReady::lib::URINotSecured;

use constant BEGINNING_MATCH => 0;
use constant FULL_MATCH => 1;

sub checkPatternSensitive($$) {
	my $reg = shift;
	my $code = shift;
	
	return () = ($$code =~ /$reg/gm);
}

sub checkPatternInsensitiveInString{
	my $code = shift;
	my $HString = shift;	
	my $PatternInString= shift;
	my $nb_detection =0;

    while ($$code =~ /(CHAINE_[0-9]+)/g)
    {
        if ($HString->{$1} =~ /["']$PatternInString["']/i)
        {
            $nb_detection++;
        }
    }

	return $nb_detection;
}


sub CountCobol($$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_ ;
	my $ret = 0;
	
	my $text;
	my $HString;

	my $checkPattern = \&checkPatternSensitive;

	$text = \$vue->{'text'};
	$HString = $vue->{'HString'};

    my $code = \$vue->{'code'};

    if ((! defined $text ) || (!defined $code)) {
		#$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HexaConstants(), $checkPattern->(qr/\b(?:VALUE|MOVE)\s+XCHAINE\_/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DISPLAY_statement(), $checkPattern->(qr/\bDISPLAY\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_CodeSkipped(), $checkPattern->(qr/\bSOURCE\-COMPUTER\s+IBM\-370\s+WITH\s+DEBUGGING\s+MODE\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_ALTER_statement(), $checkPattern->(qr/\bALTER\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_PackedDecimal(), $checkPattern->(qr/\b(?:PACKED\-DECIMAL|[^\w\-]COMP\-3)\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Binary(), $checkPattern->(qr/(?:\bBINARY\b|[^\w\-]COMP(?:[^\w\-]|\z)|[^\w\-]COMP\-4(?:[^\w\-]|\z)|[^\w\-]COMP\-5(?:[^\w\-]|\z))/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_CAPanvaletCommand(), $checkPattern->(qr/[^\w\-]\+\+(?:WRITE|INCLUDE)\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DLICalls(), checkPatternInsensitiveInString($code, $HString, '\b(?:CBLTDLI|AIBTDLI|CEETDLI|PLITDLI)\b'));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DoubleByteCharacter(), $checkPattern->(qr/\bMOVE\s+[NX]\s*CHAINE\_|\bPIC\s+[NG]\b|\bNATIONAL\-OF\b|\bDISPLAY\-OF\b|\bUSAGE\s+NATIONAL\b|\bUSAGE\s+DISPLAY\-1\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GOTO_statement(), $checkPattern->(qr/\bGO\s+TO\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DecimalPointComma(), $checkPattern->(qr/\bDECIMAL\-POINT\s+IS\s+COMMA\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_CurrencySign(), $checkPattern->(qr/\bCURRENCY\s+SIGN\s+IS\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_OccurClause(), $checkPattern->(qr/\bOCCURS?\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_RedefinesClause(), $checkPattern->(qr/\bREDEFINES\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DummyTable(), $checkPattern->(qr/\bSYSIBM\.SYSDUMMY1\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_JSONParsing(), $checkPattern->(qr/\bJSON\s+PARSE\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_XMLParsing(), $checkPattern->(qr/[^\w]\s+XML\s+PARSE\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_JSONGenerate(), $checkPattern->(qr/[^\w]\s+JSON\s+GENERATE\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UROption(), $checkPattern->(qr/\bWITH\s+UR\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SubsetRow(), $checkPattern->(qr/\bFETCH\s+FIRST\s+[0-9]+\s+ROWS\s+ONLY\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_CICSWebservice(), $checkPattern->(qr/\bEXEC\s+CICS\s+INVOKE\s+WEBSERVICE\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MQCallBatch(), checkPatternInsensitiveInString($code, $HString, '\b(?:CSQBBACK|CSQBBFMH|CSQBCB|CSQBCLOS|CSQBCOMM|CSQBCONN|CSQBCONX|CSQBCTMH|CSQBCTL|CSQBDISC|CSQBDTMH|CSQBDTMP|CSQBGET|CSQBINQ|CSQBIQMP|CSQBMHBF|CSQBOPEN|CSQBPUT|CSQBPUT1|CSQBSET|CSQBSTMP|CSQBSTAT|CSQBSUB|CSQBSUBR)\b'));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MQCall(), checkPatternInsensitiveInString($code, $HString, '\b(?:MQBACK|MQBUFMH|MQCB|MQCLOSE|MQCMIT|MQCONN|MQCONNX|MQCRTMH|MQCTL|MQDISC|MQDLTMH|MQDLTMP|MQGET|MQINQ|MQINQMP|MQMHBUF|MQOPEN|MQPUT|MQPUT1|MQSET|MQSETMP|MQSTAT|MQSUB|MQSUBRQ)\b'));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DB2Connect(), $checkPattern->(qr/\bEXEC\s+SQL\b/i, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_CASE_statement(), $checkPattern->(qr/\bEXEC\s+SQL\b.*\bCASE\b.*\bEND-EXEC\b/si, $code));


	return $ret;
}

1;
