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
#
# Liste des violations:
# Cobol::violation::violation("RU_VAR77_NOTUSED", $filename,$TabVar77l{$k},"Violation, Variable $vartemp de niveau 77 non utilisée");


# violationdebug("VAR_77", $filename,$CptLine,"Information, Declaration de $CurrentVar = $TabVar77{$CurrentVar} . ");
# violationdebug("DUP_NOM_PARA",$FICHIER,$CptLine,"Violation, Paragraphe de même nom $CurrentPara ligne $TabPara{$CurrentPara} " );
# violationdebug("VAR_77", $filename,$CptLine,"Information, Utilisation de $m = $TabVar77{$m} . ");
# violationdebug("VAR_77", $filename,$CptLine,"Information curieux, Utilisation de $m variable 77 non declarée . ");

use Cobol::violation;

my $StructFichier;
my $filename;

#Compteur
my $cptVarNotUsed = 0;

#    my %DonneesPara = ();
my %TabVar77 = ();
my %TabVar77l = ();
my %TabVar66 = ();
my %TabVar66l = ();
my %TabVar88 = ();
my %TabVar88l = ();


sub initVar($$) {
    ($StructFichier,$filename)=(@_);
    #Compteur
    $cptVarNotUsed = 0;

    %TabVar77 = ();
    %TabVar77l = ();
    %TabVar66 = ();
    %TabVar66l = ();
    %TabVar88 = ();
    %TabVar88l = ();
}

sub VarWS ($$) {
	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;

        # Nous sommes en working-storage
	if ($line =~ m{^\s+77\s+(\w[\w-]*)\s(.*)}i) {
	    my $CurrentVar = $1;
	    $TabVar77{$CurrentVar} = 1;
            $TabVar77l{$CurrentVar} = $CptLine;
	    Cobol::violation::violationInfo("VAR_77", $filename,$CptLine,"Information, Declaration de $CurrentVar = $TabVar77{$CurrentVar} . ");
	}
	if ($line =~ m{^\s+66\s+(\w[\w-]*)\s(.*)}i) {
	        my $CurrentVar = $1;
		$TabVar66{$CurrentVar} = 1;
		$TabVar66l{$CurrentVar} = $CptLine;
		Cobol::violation::violationInfo("VAR_66", $filename,$CptLine,"Information, Declaration de $CurrentVar = $TabVar66{$CurrentVar} . ");
	}
	if ($line =~ m{^\s+88\s+(\w[\w-]*)\s(.*)}i) {
	        my $CurrentVar = $1;
		$TabVar88{$CurrentVar} = 1;
		$TabVar88l{$CurrentVar} = $CptLine;
		Cobol::violation::violationInfo("VAR_88", $filename,$CptLine,"Information, Declaration de $CurrentVar = $TabVar88{$CurrentVar} . ");
	}
}

sub VarPD ($$$) {
	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;

#Essai de comptage des operandes et operateurs
	$line =~ s{\n}{}; # suppression \n
	#traitement des chaines
	$line =~ s{\".*\"}{ }g;
	$line =~ s{\'.*\'}{ }g;
	#traitement des - 
	#$line =~ s{(\w)-(\w)}{$1_$2}g;
	$line =~ s{:}{ }g; #traitement du :
	$line =~ s{\(}{ }g; #traitement de la (
	$line =~ s{\)}{ }g; #traitement de la )
	$line =~ s{\.}{}g; #traitement du .
        $line =~ s{\b(IF|END_IF|MOVE|TO|ELSE)\b}{ }gi;
	$line =~ s{\s+}{ }g;
	$line =~ s{\A\s+}{};
	my $mot;
	foreach $mot (split / /, $line) {
                my $m = uc($mot);
                if (exists $TabVar77{$m}) {
		    $TabVar77{$m}++;
		    Cobol::violation::violationdebug("VAR_77", $filename,$CptLine,"Information, Utilisation de $m = $TabVar77{$m} . ");
                } 
		else {
		 Cobol::violation::violationdebug("VAR_77", $filename,$CptLine,"Information curieux, Utilisation de $m variable 77 non declarée . ");
		}
                if (exists $TabVar66{$m}) {
		    $TabVar66{$m}++;
		    Cobol::violation::violationdebug("VAR_66", $filename,$CptLine,"Information, Utilisation de $m = $TabVar66{$m} . ");
                }
	       	else {
		    Cobol::violation::violationdebug("VAR_66", $filename,$CptLine,"Information curieux, Utilisation de $m variable 66 non declarée . ");
		}
                if (exists $TabVar88{$m}) {
		    $TabVar88{$m}++;
		    Cobol::violation::violationdebug("VAR_88", $filename,$CptLine,"Information, Utilisation de $m = $TabVar88{$m} . ");
                }
	       	else {
		    Cobol::violation::violationdebug("VAR_88", $filename,$CptLine,"Information curieux, Utilisation de $m variable 88 non declarée . ");
		}
	}

} # fin boucle ligne

sub endVar() {
    foreach my $k (keys %TabVar77) {
#	print " GGG => $k ====> VALUE  === $TabVar77{$k} \n";
        my $vartemp = $k;
        if ($TabVar77{$k} == 1) {
print "NOT USED 77 : $k\n";
	    Cobol::violation::violation("RU_VAR77_NOTUSED", $filename,$TabVar77l{$k},"Violation, Variable $vartemp de niveau 77 non utilisée");
	    $cptVarNotUsed++;
	}
    }	
    foreach my $k (keys %TabVar66) {
#	print " GGG => $k ====> VALUE  === $TabVar77{$k} \n";
        my $vartemp = $k;
        if ($TabVar66{$k} == 1) {
print "NOT USED 66 : $k\n";
	    Cobol::violation::violation("RU_VAR66_NOTUSED", $filename,$TabVar77l{$k},"Violation, Variable $vartemp de niveau 66 non utilisée");
	    $cptVarNotUsed++;
	}

    }	
    foreach my $k (keys %TabVar88) {
#	print " GGG => $k ====> VALUE  === $TabVar77{$k} \n";
        my $vartemp = $k;
        if ($TabVar88{$k} == 1) {
print "NOT USED 88 : $k\n";
	    Cobol::violation::violation("RU_VAR88_NOTUSED", $filename,$TabVar88l{$k},"Violation, Variable $vartemp de niveau 88 non utilisée");
	    $cptVarNotUsed++;
	}

    } # fin boucle

    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_VarNotUsed(),$cptVarNotUsed);	
}

1;
