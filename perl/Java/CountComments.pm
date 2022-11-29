package Java::CountComments;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Java::JavaNode;

my $CodeCommentLine__mnemo = Ident::Alias_CodeCommentLine();

my $nb_CodeCommentLine = 0;


sub CountComments($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
    # 10/11/2017 HL-333 Avoid end line comments
	my $ret = 0;
	$nb_CodeCommentLine = 0;
    
    my $viewagglo = \$vue->{'agglo'};

    my $numline=0;
    while ($$viewagglo =~ /\n/g)
    {    
        $numline++;
        my $BeginningLine = $numline;
        my $EndLine = $numline+1;

        my $index1 = $vue->{'agglo_LinesIndex'}->[$BeginningLine];
        my $index2 = $vue->{'agglo_LinesIndex'}->[$EndLine];
        # print "index $index1 a index $index2 \n";
        
        my $bloc;
        if (defined $index2) {
            $bloc = substr ($$viewagglo, $index1, ($index2-$index1));
        }
        else {
            $bloc = substr ($$viewagglo, $index1);
        }

        # list of patterns detection for end line comment inside view agglo
        # PC
        # CP

        if ($bloc  =~ /PC|CP/)
        {
            # alert
            # print 'Comment located non compliant at line '."$numline\n";
            $nb_CodeCommentLine++;
            Erreurs::VIOLATION($CodeCommentLine__mnemo, "Comment located non compliant at line $numline");
        }        
    
    }
    
    $ret |= Couples::counter_add($compteurs, $CodeCommentLine__mnemo, $nb_CodeCommentLine );

    return $ret;
    
}


1;
