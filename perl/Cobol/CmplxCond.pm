#----------------------------------------------------------------------#
#                 @ISOSCOPE 2008                                       #
#----------------------------------------------------------------------#
#       Auteur  : ISOSCOPE SA                                          #
#       Adresse : TERSUD - Bat A                                       #
#                 5, AVENUE MARCEL DASSAULT                            #
#                 31500  TOULOUSE                                      #
#       SIRET   : 410 630 164 00037                                    #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#
#
# Description: Composant de comptages sur code source COBOL

#use strict;
#use warnings;

use Cobol::violation;

my $seuil = 4;
my $cptComplexCond ;
sub CmplxCond ($$$)
{
    my($buffer,$StructFichier,$filename)=(@_);
    #Compteur
    $cptComplexCond = 0;

    my $FICHIER= $filename;
    my $CptLine = 0;


    $CptLine = $StructFichier->{"Dat_ProcDivLine"} - 1 ;

    local $/ = undef;
    my $c = $buffer;
    $c = '' if (!defined $c);
    $c =~ s/\n-//mg;
    $c =~ s/\'[^\n]*/\n/g;
    $c =~ s/\"[^\n]*/\n/g;
    my (%violation);

    # Écrabouiller commentaires
    $c =~ s{
	\*[^\n]*        |
        DISPLAY[^\n]* 
    }{
	my $match = $&;
	$match =~ s{\S+}{ }g;
	$match;
    }gixse;


#    $c =~ s{
#   	\'(\\.|[^\'])*\'
#       }{
#   	my $match = $&;
#   	$match =~ s{\S+}{ }g;
#   	$match;
#       }gxse;

    $c =~ s{\bAND\b}{\&\&}gi;

    $c =~ s{\bOR\b}{\|\|}gi;

    $c =~ s{\b(IF|MOVE|PERFORM|DIVIDE|ADD|COMPUTE|GO|GOTO|EXEC|END|EXIT|EVALUATE|UNTIL|WHEN|WHERE)\b}{µ}gi;
    $c =~ s{\w+}{}g;


    $c =~ s{-}{}g;
# On vire les . pour le moment
#    $c =~ s{\.}{µ}g; 

    $c =~ s{\.}{}g; 
#    $c =~ tr{\{\}?:,;}{,};
    $c =~ s{,}{}g;

    $c =~ s{\&\&}{a}g;
    $c =~ s{\|\|}{o}g;

    # On ne garde que ce qui nous intéresse.
    $c =~ tr/[]()µoa\n//cd;
    $c =~ s{\(\)}{}g;
#ajout flo
    $c =~ s{\(\(}{\(}g;

    $c =~ s{\)\)}{\)}g;


    # Maintenant, on n'a que des ,, des a, des o et des () et [].

    # Traitons les intérieurs des [] et ().
    my $more = 1;
 #   print "JE SUIS LA 3";
    while ($more) {
	$more = 0;
	# Parenthèses
	while ($c =~ m{\(([^\)\(\[\]]*)\)}g) {
	    $more = 1;
	    my $beg = pos($c) - length($&);
#	    print "FLO( " . $1 . "\n";
	    &check(\%violation, $FICHIER, $CptLine, $c, $beg + 1, $1);
	    my $match = $&;
	    my $nl = $match =~ tr{\n}{\n};
#    my $newLineCountflo = substr($c, 0, $beg) =~ tr{\n}{\n};
#	    $newLineCountflo = $newLineCountflo + 1;
#	    print "$fileName:$newLineCountflo + 1:FLO( " . $1 . "\n";
	    my $rep;
	    if ($match =~ tr{µ}{µ}) {
		$rep = '';
	    } else {
		$rep = $match;
		$rep =~ tr{ao}{}cd;
	    }
	    substr($c, $beg, length($match)) = $rep . ("\n" x $nl);
	    pos($c) = $beg + length($rep) + $nl;
	}
	# Crochets
	while ($c =~ m{\[([^\)\(\[\]]*)\]}g) {
	    $more = 1;
	    my $beg = pos($c) - length($&);
#	    print "FLO[ " . $1 . "\n";
	    &check(\%violation, $FICHIER, $CptLine, $c, $beg + 1, $1);
	    my $nl = substr($c, $beg, length($&)) =~ tr{\n}{\n};
	    substr($c, $beg, length($&)) = "\n" x $nl;
	    pos($c) = $beg + $nl;
	}
    }
#    print STDERR $c;
    &check(\%violation, $FICHIER, $CptLine, $c, 0, $c);

    for my $lno (sort {$a <=> $b} keys %violation) {
	print $violation{$lno};
    }

    #Ecriture des compteurs	
    Couples::counter_add($StructFichier,Ident::Alias_ComplexCond(),$cptComplexCond);
}

sub check {
    my ($violation, $fileName, $DebLine, $c, $beg, $string) = @_;

    while ($string =~ m{[oa][oa\n]*}g) {
	my $match = $&;
	my $oCount = 0;
	my $aCount = 0;
	 $oCount = $match =~ tr{o}{o};
	 $aCount = $match =~ tr{a}{a};
	if ($oCount + $aCount >= $seuil
	    && $oCount * $aCount != 0) {
#            print "$oCount + $aCount\n";
	    &violationlocal($violation, $fileName, $DebLine,
			$c, $beg + pos($string) - length($match),$oCount+$aCount );
	    $cptComplexCond++;
	}
    }
}


sub violationlocal {
    my ($violation, $fileName, $DebLine, $c, $beg, $val) = @_;

    my $newLineCount = substr($c, 0, $beg) =~ tr{\n}{\n};
    my $lineNo = $DebLine + $newLineCount + 1;
#    $V = $val;
#    print "FFF $val\n";
# Cette ligne n'a pas d'interet pour l'outil d'alarme
#    $violation ->{$lineNo} = "$fileName:$lineNo:RC_COND_COMPLEXE:Condition complexe (seuil = $seuil) valeur=${val}\n";
}

1;
