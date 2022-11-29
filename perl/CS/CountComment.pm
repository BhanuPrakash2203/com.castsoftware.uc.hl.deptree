package CS::CountComment;

use strict;
use warnings;

use Erreurs;

my $CommentedOutCode_mnemo = Ident::Alias_CommentedOutCode();
my $ParamTags_mnemo = Ident::Alias_ParamTags();
my $SeeTags_mnemo = Ident::Alias_SeeTags();
my $ReturnTags_mnemo = Ident::Alias_ReturnTags();
my $InlineComments_mnemo = Ident::Alias_InlineComments();

my $nb_CommentedOutCode = 0;
my $nb_ParamTags=0;
my $nb_SeeTags=0;
my $nb_ReturnTags=0;
my $nb_InlineComments=0;

sub CountCommentedOutCode($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_CommentedOutCode = 0;

	if ( ! defined $views->{comment} ) {
		$status |= Couples::counter_add($compteurs, $CommentedOutCode_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my @TLines = split(/\n/, $views->{comment});

	my $line_number = 0;
	for my $line (@TLines) {
		$line_number++;

		# remove comments tags
		$line =~ s/(\/\*\**|\*\/|\/\/\/*)/  /g;

		# count lines ending with ";" ou "{" ou "}"
		if ( $line =~ /[;\{}]\s*$/ ) {
			$nb_CommentedOutCode++;
			Erreurs::VIOLATION($CommentedOutCode_mnemo,"Commented out code : $line at line $line_number");
			next;
		}

		# count lines beginning with "for", "while", ...
		elsif ( $line =~ /^\s*(if\s*\(|else\b|while\s*\(|for\s*\(|foreach\s*\(|switch\s*\(|case\b.*:|default\s*:)/ ) { 
			$nb_CommentedOutCode++;
			Erreurs::VIOLATION($CommentedOutCode_mnemo,"Commented out code : $line at line $line_number");
			next;
		}
	}
	$status |= Couples::counter_add($compteurs, $CommentedOutCode_mnemo, $nb_CommentedOutCode);

	return $status;
} 

sub CountAutodocTags ($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;

	my $status = 0;
	$nb_ParamTags=0;
	$nb_SeeTags=0;
	$nb_ReturnTags=0;

	if ( ! defined $vue->{comment} ) {
		$status |= Couples::counter_add($compteurs, Ident::Alias_ParamTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, Ident::Alias_SeeTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, Ident::Alias_ReturnTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	# <param name="name">description</param>
	$nb_ParamTags = () = $vue->{comment} =~ /<[Pp]aram\b[^>\n]*>/g;
  
	$nb_SeeTags = () = $vue->{comment} =~ /<[Ss]ee\b[^>\n]*>/g;
	$nb_ReturnTags = () = $vue->{comment} =~ /<[Rr]eturns?\b[^>\n]*>/g;

	$status |= Couples::counter_add($compteurs, $ParamTags_mnemo, $nb_ParamTags );
	$status |= Couples::counter_add($compteurs, $SeeTags_mnemo, $nb_SeeTags );
	$status |= Couples::counter_add($compteurs, $ReturnTags_mnemo, $nb_ReturnTags );

	return $status;
}

sub CountInlineComments ($$$) {
	my ($fichier, $view, $compteurs) = @_ ;

	my $status = 0;
	$nb_InlineComments = 0;
	
	my $agglo = \$view->{'agglo'};
	
	if ( ! defined $agglo ) {
		$status |= Couples::counter_add($compteurs, Ident::Alias_InlineComments(), Erreurs::COMPTEUR_ERREUR_VALUE );

		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $line = 1;
	while ($$agglo =~ /(\n|PC|CP)/sg) {
		if ($1 eq "\n") {
			$line++;
		}
		else {
			$nb_InlineComments++;
			Erreurs::VIOLATION($InlineComments_mnemo,"Inlinecomment at line $line");
		}
	}

	$status |= Couples::counter_add($compteurs, $InlineComments_mnemo, $nb_InlineComments );

	return $status;
}

1;
