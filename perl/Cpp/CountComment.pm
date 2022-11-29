package Cpp::CountComment;

use strict;
use warnings;

use Erreurs;
use Cpp::ParserIdents;
use Lib::NodeUtil;
use Cpp::CppNode;

my $DEBUG = 0;

my $mnemo_SuspiciousCommentSyntax = Ident::Alias_SuspiciousCommentSyntax();

my $nb_SuspiciousCommentSyntax = 0;


###############################################################################################################""""

# HL-693 Avoid /* sequence inside C-style comment
sub CountComment($$$$) {
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;

    $nb_SuspiciousCommentSyntax = 0;
  
    my $Comment = \$vue->{'comment'}||[];

    if ( ! defined $Comment )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_SuspiciousCommentSyntax, Erreurs::COMPTEUR_ERREUR_VALUE );
    }
    
    my $count_OpeningMultiComment;
    my $numLine;
    while ($$Comment =~ /\G((\/\*)|(\*\/)|(\n)|\/|\*|[^\/\*\n]*)/gc)
    { 
        if (defined $2)
        {
            $count_OpeningMultiComment++;
        }
        elsif (defined $3)
        {
            $count_OpeningMultiComment--; # eliminate first opening comment
            
            if ($count_OpeningMultiComment > 0)
            {
                Erreurs::VIOLATION($mnemo_SuspiciousCommentSyntax, "Unexpected /* sequence inside /* ... */ comment at line ".$numLine);
				print "+++++ Unexpected /* sequence inside /* ... */ comment at line ".$numLine."\n" if ($DEBUG);
				$nb_SuspiciousCommentSyntax = $count_OpeningMultiComment;
            }

            # initialize counter
            $count_OpeningMultiComment = 0;
        }
        
        $numLine++ if (defined $4);
    }
    
    $status |= Couples::counter_add ($compteurs, $mnemo_SuspiciousCommentSyntax, $nb_SuspiciousCommentSyntax);

    return $status;
}

1;
