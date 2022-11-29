package Python::CountComment;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;

my $UnCommentedClasses__mnemo = Ident::Alias_UnCommentedClasses();
my $UnCommentedRoutines__mnemo = Ident::Alias_UnCommentedRoutines();
my $InlineComments__mnemo = Ident::Alias_InlineComments();
my $LinesOfCode__mnemo = Ident::Alias_LinesOfCode();
my $CommentBlocs__mnemo = Ident::Alias_CommentBlocs();
my $MissingBlankLines__mnemo = Ident::Alias_MissingBlankLines();
my $CommentLines__mnemo = Ident::Alias_CommentLines();

my $nb_UnCommentedClasses = 0;
my $nb_UnCommentedRoutines = 0;
my $nb_InlineComments = 0;
my $nb_LinesOfCode = 0;
my $nb_CommentBlocs = 0;
my $nb_MissingBlankLines = 0;
my $nb_CommentLines = 0;


sub isCommentedArtifact($$$) {
	my $artifact = shift;
	my $r_MixBloc = shift;
	my $MixBloc_LinesIndex = shift;
	
	my $artifactLine = GetLine($artifact);
	
	# FIXME : put in the right location ... use view code instead ? 
	#pos($$r_MixBloc) = $MixBloc_LinesIndex->[$artifactLine-2];
	#if ($$r_MixBloc =~ /[^\n]*\n[^\n]*\n/) {
	#}
	
	my $artifactIndent = getPythonKindData($artifact, 'indentation');
	pos($$r_MixBloc) = $MixBloc_LinesIndex->[$artifactLine + 1 + getPythonKindData($artifact, 'lines_in_proto')];
	while ($$r_MixBloc =~ /\G(?:${artifactIndent}[ \t]+(#%|\S))?[^\n]*\n/g) {
		# Empty line ? 
		if (defined $1) {
				# Docstring encountered ?
				if ($1 eq '#%') {
					# OK, artifact is commented
					return 1;
				}
				else {
					# code line that is not a docstring => artifact is not commentd
					last;
				}
		}
	}
	return 0;
}

sub CountComments($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	my $ret =0;
	
	$nb_InlineComments = 0;
	$nb_LinesOfCode = 0;
	$nb_CommentBlocs = 0;
	$nb_CommentLines = 0;
	
	
	my $agglo = \$vue->{'agglo'} ;
	
	if ( ! defined $agglo )  {
		$ret |= Couples::counter_add($compteurs, $InlineComments__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $LinesOfCode__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $CommentBlocs__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $CommentLines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	$nb_LinesOfCode = () = $$agglo =~ /(P|\@)/g;
	
	$nb_CommentLines = () = $$agglo =~ /(#|")/g;

	$nb_CommentBlocs = () = $$agglo =~ /("|(?:#\n)+)/g;
#print "COMMENT BLOCS : $nb_CommentBlocs\n";
	# IN the agglo view, each inline comment is identified by a non-blanl character followed by a #
	$nb_InlineComments = () = $$agglo =~ /(^.*\S#$)/gm;
#print "--> InlineComments : $nb_InlineComments\n";
	$ret |= Couples::counter_add($compteurs, $InlineComments__mnemo, $nb_InlineComments );
	$ret |= Couples::counter_add($compteurs, $LinesOfCode__mnemo, $nb_LinesOfCode );
	$ret |= Couples::counter_add($compteurs, $CommentBlocs__mnemo, $nb_CommentBlocs );
	$ret |= Couples::counter_add($compteurs, $CommentLines__mnemo, $nb_CommentLines );
	
	return $ret;
}


sub CountUnCommentedArtifact($$$) {
	my ($file, $vue, $compteurs) = @_ ;

	my $ret = 0;
	$nb_UnCommentedClasses = 0;
	$nb_UnCommentedRoutines = 0;
	$nb_MissingBlankLines = 0;

	my $KindNodesList = $vue->{'KindsLists'};
	my $MixBloc = \$vue->{'MixBloc'};
	my $MixBloc_LinesIndex = $vue->{'MixBloc_LinesIndex'};
	my $tabagglo = $vue->{'tabagglo'};

	if (( ! defined $MixBloc ) || (!defined $MixBloc_LinesIndex)) {
		$ret |= Couples::counter_add($compteurs, $UnCommentedClasses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	#if ( ! defined $tabagglo ) {
	#	$ret |= Couples::counter_add($compteurs, $MissingBlankLines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
	#	return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	#}

	if (defined $KindNodesList) {
		for my $class (@{$KindNodesList->{&ClassKind}}) {
			if (! isCommentedArtifact($class, $MixBloc, $MixBloc_LinesIndex)) {
				Erreurs::VIOLATION($UnCommentedClasses__mnemo, "Class ".GetName($class)." is not commented at line ".GetLine($class));
				$nb_UnCommentedClasses++;
			}
			
			my $topLevel = IsKind(GetParent($class), RootKind);
			
			my $classLine = GetLine($class);
			if ($classLine > 2) {
				# get the index of the line preceding the class ...
				my $idxLine = $classLine-2;
				
				while ($idxLine && ($tabagglo->[$idxLine] =~ /^[\@#"]/m)) {
					$idxLine--;
				}
				# check the two lines before the class declaration ...
				if ( ($tabagglo->[$idxLine] ne '') ||
					 (($topLevel) && ($tabagglo->[$idxLine-1] ne ''))) {
						$nb_MissingBlankLines++;
						Erreurs::VIOLATION($MissingBlankLines__mnemo, "Missing double empty line before Class ".GetName($class)." at line ".GetLine($class));
				}
			}
		}

		my @funcs = (@{$KindNodesList->{&FunctionKind}},
					 @{$KindNodesList->{&MethodKind}});
		for my $func (@funcs) {
			if (! isCommentedArtifact($func, $MixBloc, $MixBloc_LinesIndex)) {
				Erreurs::VIOLATION($UnCommentedRoutines__mnemo, "Routine ".GetName($func)." is not commented at line ".GetLine($func));
				$nb_UnCommentedRoutines++;
			}
			
			my $funcLine = GetLine($func);
			if ($funcLine > 1) {
				# get the index of the line preceding the function ...
				my $idxLine = $funcLine-2;
				
				my $topLevel = IsKind(GetParent($func), RootKind);
				
				while ($idxLine && ($tabagglo->[$idxLine] =~ /^[\@#"]/m)) {
					$idxLine--;
				}
				# check the two lines before the function declaration ...
				if (	($tabagglo->[$idxLine] ne '') ||
						(($topLevel) && ($tabagglo->[$idxLine-1] ne ''))) {
					$nb_MissingBlankLines++;
					Erreurs::VIOLATION($MissingBlankLines__mnemo, "Missing empty line before function ".GetName($func)." at line ".$funcLine);
				}
			}
		}
		
		$ret |= Couples::counter_add($compteurs, $MissingBlankLines__mnemo, $nb_MissingBlankLines );
		$ret |= Couples::counter_add($compteurs, $UnCommentedClasses__mnemo, $nb_UnCommentedClasses );
		$ret |= Couples::counter_add($compteurs, $UnCommentedRoutines__mnemo, $nb_UnCommentedRoutines );
	}
	else {
		$ret |= Couples::counter_add($compteurs, $UnCommentedClasses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	return $ret;
}


1;


