package JSP::CountComment;

use strict;
use warnings;

use Erreurs;

use Lib::NodeUtil;
use JSP::JSPScriptNode;
use JSP::JSPLib;
require JSP::GlobalMetrics;

my $MissingJSPComment__mnemo = Ident::Alias_MissingJSPComment();
my $MultipleComments__mnemo = Ident::Alias_MultipleComments();
my $UncommentedProperty__mnemo = Ident::Alias_UncommentedProperty();

my $nb_MissingJSPComment = 0;
my $nb_MultipleComments = 0;
my $nb_UncommentedProperty = 0;

sub CountMissingJSPComment($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

	$nb_MissingJSPComment = 0;
    
	my $Mix = $vue->{'MixBloc'};
    
    if ( ! defined $Mix ) {
		$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	
	$Mix =~ s/\/\*(?:\*[^\/]|[^*])*\*\//__HIGHLIGHT_COMMENT__/g;

	$Mix =~ s/<jsp:scriptlet>/<%/g;
	$Mix =~ s/<\/jsp:(?:scriptlet|declaration|expression)\s*>/%>/g;
	
	$Mix =~ s/<jsp:declaration>/<%!/g;
	$Mix =~ s/<jsp:expression>/<%=/g;
	
	$nb_MissingJSPComment = () = $Mix =~ /<%[=!]?\s*(?:__HIGHLIGHT_COMMENT__\s*)*%>/g;
	$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, $nb_MissingJSPComment );
	
	return $ret;
}

sub CountMultipleComments($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

	$nb_MultipleComments = 0;

	my $script = $vue->{'script_html'};

	if ( ! defined $script ) {
		$ret |= Couples::counter_add($compteurs, $MultipleComments__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	$nb_MultipleComments = () = $script =~ /--%>\s*<%--/sg;

	# Normalization of // comment to /**/
	# 1 - replace // ....... %>    with  /**/%> 
	$script =~ s/\/\/[^\n%]*%>/\/\*\*\/%>/sg;
	# 2 - replace // ........\n    with  /**/\n
	$script =~ s/\/\/[^\n]*\n/\/\*\*\/\n/sg;
	$nb_MultipleComments += () = $script =~ /\*\/\s*\/\*/sg;

	$ret |= Couples::counter_add($compteurs, $MultipleComments__mnemo, $nb_MultipleComments );
	
	return $ret;
}

sub CountUncommentedProperty($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

	$nb_UncommentedProperty = 0;

	my $script = $vue->{'script_html'};
	my $strings = $vue->{'script_string'};

	if (( ! defined $script ) || ( ! defined $strings )) {
		$ret |= Couples::counter_add($compteurs, $UncommentedProperty__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $nb_Property = 0;
	while ($script =~ /(--%>\s*)?<jsp:setProperty\b([^>]*)>/sg) {
		$nb_Property++;
		if (!defined $1) {
			my $stmt = $2;
			my $value = JSP::JSPLib::getTagAttribute(\$stmt, "property", $strings->{'strings_values'});
			if ((defined $value) && ($value eq "*")) {
				$nb_UncommentedProperty++;
			}
		}
	}
	
	$ret |= Couples::counter_add($compteurs, $UncommentedProperty__mnemo, $nb_UncommentedProperty);
	
	return $ret;
}

1;
