package Swift::CountClass;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Swift::SwiftNode;
use Swift::Identifiers;
use Swift::SwiftConfig;

my $DEBUG = 0;

my $EmptyClasses__mnemo = Ident::Alias_EmptyClasses();

my $nb_EmptyClasses= 0;

sub CountClass($$$) 
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_EmptyClasses = 0;

    my $root =  \$vue->{'code'} ;
    my $MixBloc_NumLinesComment = $vue->{'MixBloc_NumLinesComment'};

    if ( ( ! defined $root ) )
    {
        $ret |= Couples::counter_add($compteurs, $EmptyClasses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
	my @classes = @{$vue->{'KindsLists'}->{'ClassDeclaration'}};

     for my $class (@classes) {

         my $children = GetChildren ($class);
         if (scalar @{$children} == 0 ){
             my $beginningLine = Lib::NodeUtil::GetLine($class);
             my $endingLine = Lib::NodeUtil::GetEndline($class);

              my $boolComment = 0;
              for (my $numLine = $beginningLine; $numLine <= $endingLine; $numLine++) {
                  if (exists $MixBloc_NumLinesComment->{$numLine}) {
                      $boolComment = 1;
                  }
              }
             # HL-1090 : Classes should not be empty
              if ($boolComment == 0) {
                  # print "VIOLATION empty class !! at line " . Lib::NodeUtil::GetLine($class) . "\n";
                  $nb_EmptyClasses++;
                  Erreurs::VIOLATION($EmptyClasses__mnemo, "Empty class at line ".GetLine($class).".");
              }
         }
     }

    $ret |= Couples::counter_add($compteurs, $EmptyClasses__mnemo, $nb_EmptyClasses );

    return $ret;
}



1;
