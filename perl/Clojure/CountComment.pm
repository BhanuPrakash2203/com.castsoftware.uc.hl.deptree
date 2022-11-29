package Clojure::CountComment;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Clojure::ClojureNode;
use Clojure::Config;

my $MissingSpaceAfterCommentDelimiter__mnemo = Ident::Alias_MissingSpaceAfterCommentDelimiter();
my $CommentedOutCode__mnemo = Ident::Alias_CommentedOutCode();

my $nb_MissingSpaceAfterCommentDelimiter = 0;
my $nb_CommentedOutCode = 0;

sub CountComment($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_MissingSpaceAfterCommentDelimiter = 0;

	my $comment = \$vue->{'comment'};
  
	if ( ! defined $comment )
	{
		$ret |= Couples::counter_add($compteurs, $MissingSpaceAfterCommentDelimiter__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $line = 1;
	while ( $$comment =~ /(;[^;\s])||(\n)/g) {
		if (defined $1) {
			$nb_MissingSpaceAfterCommentDelimiter ++;
			Erreurs::VIOLATION($MissingSpaceAfterCommentDelimiter__mnemo,"Missing space after semicolon at line $line");
		}
		elsif (defined $2) {
			$line++;
		}
	}
	
	$ret |= Couples::counter_update($compteurs, $MissingSpaceAfterCommentDelimiter__mnemo, $nb_MissingSpaceAfterCommentDelimiter );
	
    return $ret;
}

sub CountCommentedOutCode($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
	$nb_CommentedOutCode = 0;
	
	my $comment = \$vue->{'comment'};
	
	if ( ! defined $comment )
	{
		$ret |= Couples::counter_add($compteurs, $CommentedOutCode__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $line = 1;
	
	while ( $$comment =~ /(#_\()|(\n)/g ) {
		if (defined $1) {
			$nb_CommentedOutCode++;
			Erreurs::VIOLATION($CommentedOutCode__mnemo,"Commented out code at line $line");
		}
		else {
			$line++;
		}
	}
	
	$ret |= Couples::counter_update($compteurs, $CommentedOutCode__mnemo, $nb_CommentedOutCode );
	
    return $ret;
}

1;


