package PHP::Parse;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use CountUtil;

use Lib::Node qw( Leaf Node Append );

use PHP::PHPNode ;
use PHP::PHPNode qw( SetName SetStatement SetLine GetLine); 
use PHP::ParsePHP;

my $DEBUG = 0;


# description: PHP parse module Entry point.
sub Parse($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;

#    my $statements =  $vue->{'statements_with_blanks'} ;

     my ($PHPNode, $Artifacts) = PHP::ParsePHP::ParsePHP(\$vue->{'code'});

#     splitCompoundStatement();

#      my @statementReader = ( $statements, 0);
#

#     my $rootNode = ParseUtil::parseRoot();

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

      #Lib::Node::Dump($PHPNode, *STDERR, "ARCHI") if ($DEBUG);
      #print STDERR ${Lib::Node::dumpTree($PHPNode, "ARCHI")} ;
      
      $vue->{'structured_code'} = $PHPNode;

      $vue->{'artifact'} = $Artifacts;

      #TSql::ParseDetailed::ParseDetailed($vue);
      if ($DEBUG) {
      for my $key ( keys %{$vue->{'artifact'}} ) {
        print "-------- $key -----------------------------------\n";
	print  $vue->{'artifact'}->{$key}."\n";
      }
      }

    return $status;
}

1;
