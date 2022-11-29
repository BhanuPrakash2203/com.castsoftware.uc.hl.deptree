package JSP::CountDirective;

use strict;
use warnings;

use Erreurs;

use Lib::NodeUtil;
use JSP::JSPScriptNode;
require JSP::GlobalMetrics;

my $UselessTaglib__mnemo = Ident::Alias_UselessTaglib();
my $StdSQLuse__mnemo = Ident::Alias_StdSQLuse();
my $StarImport__mnemo = Ident::Alias_StarImport();

my $nb_UselessTaglib = 0;
my $nb_StdSQLuse = 0;
my $nb_StarImport = 0;

sub getPrefix($$$) {
	my $content = shift;
	my $strings = shift;
	my $list = shift;
	
	my $prefix = undef;
	 
	if ($content =~ /prefix=\s*(\w+)/) {
		$prefix = $strings->{$1};
		if (defined $prefix) {
			$prefix =~ s/["']//g;
			# record the taglib prefix in the list of imported taglib.
			push @{$list}, $prefix;
		} 
	}
	return undef;
}

sub countImport($$) {
	my $tag_content = shift;
	my $strings = shift;
	
	if ($tag_content =~ /\bimport\s*=\s*(\w+)/) {
		my $import = $strings->{$1};
	
		if ($import =~ /\A["']javax?\.sql\./i) {
			$nb_StdSQLuse++;
		}
		
		if ($import =~ /\*/i) {
			$nb_StarImport++;
		}
		
	}
}

sub _cb_Directive() {
	my ($node, $context) = @_;
	my $strings = $context->[2];
	
	my $kind = Lib::NodeUtil::GetKind($node);
	my $stmt = Lib::NodeUtil::GetStatement($node);
	
	if ($kind eq JSP_TAG_LIB) {
		my $name = Lib::NodeUtil::GetName($node);
	
		if ($name =~ /(\w+):\w+/) {
			# record the tag name in the Hash of tags used.
			$context->[1]->{$1} = 1;
		}
	}
	elsif (($kind eq STD_JSP_TAG) || ($kind eq STD_JSP_DIRECTIVE)) {
		if ($$stmt =~ /<\%\s*\@\s*(?:(taglib)|(page))\b([^>]*)\%>/i) {
			if (defined $1) {
				# taglib
				getPrefix($3, $strings, $context->[0]);
			}
			elsif (defined $2)	{
				# page
				countImport($3, $strings);
			}
		}
	}
	elsif ($kind eq XML_JSP_TAG) {
		if ($$stmt =~ /<\s*jsp:directive\.(?:(taglib)|(page))\b([^>]*)\/>/i) {
			if (defined $1) {
				# taglib
				my $prefix = getPrefix($3, $strings, $context->[0]);
			}
			elsif (defined $2) {
				# page
				countImport($3, $strings);
			}
		}
	}
	return undef;
}

sub countTaglib($$) {
	my $importedTags = shift;
    my $usedTags = shift;

	# search unused imported tags.
	for my $tag (@$importedTags) {
		if (! exists $usedTags->{$tag}) {
			$nb_UselessTaglib++;
		}
	}
}

sub CountDirective($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

	$nb_UselessTaglib = 0;
    $nb_StdSQLuse = 0;
    $nb_StarImport = 0;
    
	my $tags = $vue->{'tag_tree'};
	my $strings = $vue->{'script_string'}->{'strings_values'};
    
    if ((! defined $tags) || (! defined $strings)){
		$ret |= Couples::counter_add($compteurs, $UselessTaglib__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $StdSQLuse__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $StarImport__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	# Get tags used ...
	my @importedTags = ();
	my %usedTags = ();
	my @context = (\@importedTags, \%usedTags, $strings);
	Lib::Node::Iterate($tags, 0, \&_cb_Directive, \@context);

    countTaglib(\@importedTags, \%usedTags);

	$ret |= Couples::counter_add($compteurs, $UselessTaglib__mnemo, $nb_UselessTaglib );
	$ret |= Couples::counter_add($compteurs, $StdSQLuse__mnemo, $nb_StdSQLuse );
	$ret |= Couples::counter_add($compteurs, $StarImport__mnemo, $nb_StarImport );
}

1;
