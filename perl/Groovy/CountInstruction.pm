package Groovy::CountInstruction;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;
use Groovy::Config;

use Groovy::GroovyNode;

my $CaseLengthAverage__mnemo = Ident::Alias_CaseLengthAverage();
my $SmallSwitchCase__mnemo = Ident::Alias_SmallSwitchCase();
my $UnconditionalJump__mnemo = Ident::Alias_UnconditionalJump();
my $EmptyStatementBloc__mnemo = Ident::Alias_EmptyStatementBloc();
my $LongCase__mnemo = Ident::Alias_LongCase();
my $mnemo_ComplexOperands = Ident::Alias_ComplexOperands();

my $nb_caseLenghtAverage = 0;
my $nb_SmallSwitchCase = 0;
my $nb_UnconditionalJump = 0; 
my $nb_EmptyStatementBloc = 0;
my $nb_LongCase = 0;
my $nb_ComplexOperands = 0;

sub CountInstruction($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    $nb_caseLenghtAverage = 0;
    $nb_SmallSwitchCase = 0;
    $nb_UnconditionalJump = 0;
    $nb_EmptyStatementBloc = 0;
    $nb_LongCase = 0;
   
	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $CaseLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $SmallSwitchCase__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnconditionalJump__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $EmptyStatementBloc__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $LongCase__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $caseInstr = $KindsLists->{&CaseKind};
	my $ifInstr = $KindsLists->{&IfKind};
	my $elseInstr = $KindsLists->{&ElseKind};
	my $whileInstr = $KindsLists->{&WhileKind};
	my $forInstr = $KindsLists->{&ForKind};
	my $tryInstr = $KindsLists->{&TryKind};
	my $switchInstr = $KindsLists->{&SwitchKind};
	my $finallyInstr = $KindsLists->{&FinallyKind};
    my $countCases;
    my $TotalCaseLenght;

    # 18/12/2017 HL-332 Avoid long case statements    
	for my $case (@{$caseInstr}) 
    {
		    
        my $beginLineCase = GetLine ($case);
        my $endLineCase = GetEndline ($case);    
            
        my $lenghtCase = $endLineCase - $beginLineCase;
        
        if ($lenghtCase > Groovy::Config::CASE_LENGTH_THRESHOLD) {
			$nb_LongCase++;
		}
        
        
        $TotalCaseLenght+= $lenghtCase;
        $countCases++;
	}
    
    #print 'TotalCaseLenght='.$TotalCaseLenght."\n";
    #print 'countCases='.$countCases."\n";
    if ($countCases) {
		$nb_caseLenghtAverage = int($TotalCaseLenght/$countCases);
	}
	else {
		$nb_caseLenghtAverage = 0;
	}
    
    # print 'caseLenghtAverage='.$caseLenghtAverage."\n";
    Erreurs::VIOLATION($CaseLengthAverage__mnemo, "Case length average is $nb_caseLenghtAverage");

    # 19/11/2020 HL-1550 Avoid empty statements blocs
    for my $if (@{$ifInstr}) {
        my $thenNode = GetChildren($if)->[1];
        if (scalar @{GetChildren($thenNode)} == 0) {
            # print "Empty statements blocs [if] at line " . GetLine($if) . "\n";
            $nb_EmptyStatementBloc++;
            Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Empty statements blocs [if] at line " . GetLine($if));
        }
    }
    for my $else (@{$elseInstr}) {
        if (scalar @{GetChildren($else)} == 0) {
            # print "Empty statements blocs [else] at line " . GetLine($else) . "\n";
            $nb_EmptyStatementBloc++;
            Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Empty statements blocs [else] at line " . GetLine($else));
        }
    }
    for my $while (@{$whileInstr}) {
        my $thenNode = GetChildren($while)->[1];
        if (scalar @{GetChildren($thenNode)} == 0) {
            # print "Empty statements blocs [while] at line " . GetLine($while) . "\n";
            $nb_EmptyStatementBloc++;
            Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Empty statements blocs [while] at line " . GetLine($while));
        }
    }
    for my $for (@{$forInstr}) {
        my $thenNode = GetChildren($for)->[1];
        if (scalar @{GetChildren($thenNode)} == 0) {
            # print "Empty statements blocs [for] at line " . GetLine($for) . "\n";
            $nb_EmptyStatementBloc++;
            Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Empty statements blocs [for] at line " . GetLine($for));
        }
    }
    for my $try (@{$tryInstr}) {
        my $thenNode = GetChildren($try)->[0];
        if (scalar @{GetChildren($thenNode)} == 0) {
            # print "Empty statements blocs [try] at line " . GetLine($try) . "\n";
            $nb_EmptyStatementBloc++;
            Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Empty statements blocs [try] at line " . GetLine($try));
        }
    }
    for my $finally (@{$finallyInstr}) {
        if (scalar @{GetChildren($finally)} == 0) {
            # print "Empty statements blocs [finally] at line " . GetLine($finally) . "\n";
            $nb_EmptyStatementBloc++;
            Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Empty statements blocs [finally] at line " . GetLine($finally));
        }
    }

    # HL-404 Avoid small switch/Case
    # number of case or default instructions (CaseKind + DefaultKind)
    # if number < 3 => violation

	for my $switch (@{$switchInstr}) 
    {    
        my $ref_children_niv1 = GetChildren($switch);
		my $countCasePerSwitch = 0;
        
        foreach my $child_niv1 (@{$ref_children_niv1})
        {      
            
            # print "child=" . GetKind ($child) ."\n";
            my $ref_children_niv2 = GetChildren($child_niv1);
            
            foreach my $child_niv2 (@{$ref_children_niv2})
            {                 
                if ( GetKind ($child_niv2) eq CaseKind or GetKind ($child_niv2) eq DefaultKind )
                {
                    # print "child=" . GetKind ($child_niv2) ."\n";
                    $countCasePerSwitch++;
#print "CASE or DEFAULT\n";
                    
                    # 10/01/2018 HL-405 Avoid unconditional jump statement 
                    my $ref_children_niv2 = GetChildren($child_niv2);
                                   
                    foreach my $child_niv3 (@{$ref_children_niv2})
                    {        

                        if ( GetKind ($child_niv3) eq BreakKind )
                        {
                            # print '2++++++' . GetKind ($child)."\n";
                            my $nextSibling = Lib::Node::GetNextSibling($child_niv3);
                            
							if ($nextSibling) {
								$nb_UnconditionalJump++;
								Erreurs::VIOLATION($UnconditionalJump__mnemo, "Unconditional jump at line ".GetLine($child_niv3));
							}
                        }
                    }
                }
            }
        }
        
	    if ($countCasePerSwitch < 3) {
			$nb_SmallSwitchCase++;
			Erreurs::VIOLATION($SmallSwitchCase__mnemo, "Small switch/case at line ".GetLine($switch));
		}

        # 19/11/2020 HL-1550 Avoid empty statements blocs
        my $thenNode = GetChildren($switch)->[1];
        if (scalar @{GetChildren($thenNode)} == 0){
            # print "Empty statements blocs [switch] at line ".GetLine($switch)."\n";
            $nb_EmptyStatementBloc++;
            Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Empty statements blocs [switch] at line ".GetLine($switch));
        }
    }
	
    $ret |= Couples::counter_add($compteurs, $CaseLengthAverage__mnemo, $nb_caseLenghtAverage );
    $ret |= Couples::counter_add($compteurs, $SmallSwitchCase__mnemo, $nb_SmallSwitchCase );
    $ret |= Couples::counter_update($compteurs, $UnconditionalJump__mnemo, $nb_UnconditionalJump );
    $ret |= Couples::counter_add($compteurs, $EmptyStatementBloc__mnemo, $nb_EmptyStatementBloc );
    $ret |= Couples::counter_add($compteurs, $LongCase__mnemo, $nb_LongCase );
    
    return $ret;
    
}

#-------------------------------------------------------------------------------
# *************** COMPLEX OPERANDS **********************
# Cound expressions with too high level of dereferencements
#-------------------------------------------------------------------------------

my $ComplexitySeuil = 4;
my $LINE = 1;
sub CountComplexOperands ($$$$) {

  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $mnemo_ComplexOperands = Ident::Alias_ComplexOperands();
  my $status = 0;
  my $LINE = 1;
  #my $code = $vue->{'code'} ;
  
  # The buffer is dupplicated because the algorithm modifies it in the function 
  # CountComplexDeref().
  my $code = ${Vues::getView($vue, 'code')};

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_ComplexOperands, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nb_ComplexOperands = 0;

  $nb_ComplexOperands += CountComplexDeref (\$code, \$fichier, \$options);

  $status |= Couples::counter_add($compteurs, $mnemo_ComplexOperands, $nb_ComplexOperands);

  return $status;
}

#--------------------------------------------------------------------------------
# ALGO : on splitte le code selon les operateurs d'indirection '.', '->' et '['.
# Chaque token consécutif qui ne comporte que des caracteres ':alphanum:blanc:() ou ]'
# constitue un nouveau niveau d'indirection puisqu'il est forcement separe du precedent
# par un operateur d'indirection (compte tenu du split sur ces operateurs)
# La chaine d'indirection est rompue lorsqu'un token comporte un autre caractere que ceux listes
# plus haut. Ce token marque donc le dernier niveau d'indirection.
#--------------------------------------------------------------------------------

my $DEREF_OPERATORS = qr/\.|\->|\[/;
sub CountComplexDeref_InsideSubexpr($$);
sub CountComplexDeref_InsideSubexpr($$) {
	my $expr = shift;
	my $level = shift;

	my $lDeref = 0;
	my $nb_DeepDeref = 0;
	
	my $other_token="";
	my $deref_end = 0;
	my $subexpr_end = 0;
	my $derefExpr = "";
	my $derefLine = 0;
	my $previousToken = "";
	my $b_derefContinuingNextLine = 0;
	# split on deref item and manage open/close that introduce sub-expressions.
	while ($$expr =~ /\G(?:(\.|\->|\[)|(\()|(\)|\])|(\-|\n|[^\.\-\[\]\(\)\n]*))/gc) {
		# $1 is a deref operator
		# $2 is an openning introducing a sub expr
		# $3 is a closing endind a subexpr
		# $4 is all other tokens
		$other_token = $4;
		
		if ((defined $other_token ) && ($other_token =~ /^[ 	]+$/m)) {
			$derefExpr .= $other_token;
			next;
		}
		
		# DEREF
		if (defined $1) {
			$previousToken = $1;
			# new deref level
			$lDeref++;
			$derefLine = $LINE if ($lDeref == 1);
			if ($1 eq '[') {
				$nb_DeepDeref += CountComplexDeref_InsideSubexpr($expr, $level+1);
				$derefExpr .= '[...]';
			}
			else {
				$derefExpr .= $1;
			}
		}
		else {

			if (($previousToken eq "\n") && ($lDeref > 0) && (!$b_derefContinuingNextLine)) {
				$deref_end = 1;
			}
			
			# END SUBEXPR
			if (defined $3) {
				$previousToken = $3;
				# end of sub expression
				#if ($lDeref > 0) {
					$deref_end = 1;
					$subexpr_end = 1;
					$derefExpr .= $3;
				#}
			}
			# BEGIN SUBEXPR
			elsif (defined $2) {
				$previousToken = $2;
				# begin of sub expression
				$nb_DeepDeref += CountComplexDeref_InsideSubexpr($expr, $level+1);
				$derefExpr .= '(...)';
			}
			# OTHERS
			else {
				$other_token = $4;
				
				$LINE++ if ($other_token eq "\n");
				
				if (($other_token eq "\n") && ($previousToken =~ /$DEREF_OPERATORS/)) {
					$b_derefContinuingNextLine = 1;
				}
				$previousToken = $other_token;
			
				$derefExpr .= $other_token;
				# Si le token contient des caracteres autres que ceux autorises dans une expression de dereferencement, alors il s'agit
				# d'un debut de dereferencement (a comptabiliser), ou d'une fin de dereferencement (a ne pas comptabiliser).
				if ( ($lDeref) && ($other_token =~ /[^\w\]\s\(\)<>]/s )) {
					# END of dereferencement expression
					$deref_end = 1;
				}
			}
		}

		if ($deref_end) {
			if ( $lDeref > $ComplexitySeuil) {
				$nb_DeepDeref++;
				Erreurs::VIOLATION($mnemo_ComplexOperands, "Complex operand at line : $derefLine");
			}
#print STDERR "FULL DEREF (nb=$lDeref) : $derefExpr\n" if $lDeref;
			$lDeref = 0;
			$deref_end = 0;
			$derefExpr = "";
		}
		
		# return only if the level is more than 1. Indeed, if we are in the first level, returning will end the diag, whereas it would be an error.
		# If the open/close are correctly matched, it is impossible to leave the level 1.
		if ($subexpr_end) {
			if ($level > 1) {
				last;
			}
			else {
				$subexpr_end = 0;
				$derefExpr = "";
			}
		}
	}

	return $nb_DeepDeref;
}

sub CountComplexDeref($$$) {

  my ($expr, $fichier, $options) = @_ ;

  my $mnemo_ComplexOperands = Ident::Alias_ComplexOperands();
  my $b_TraceDetect = ((exists $$options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces
  my $trace_detect = '' if ($b_TraceDetect); # Erreurs::LogInternalTraces
  my $base_filename = $$fichier if ($b_TraceDetect); # Erreurs::LogInternalTraces
  $base_filename =~ s{.*/}{} if ($b_TraceDetect); # Erreurs::LogInternalTraces
  my $line_number = 1 if ($b_TraceDetect); # Erreurs::LogInternalTraces

  # Neutralisation des nombres decimaux :
  $$expr =~ s/\d+\.\d+/0/sg ;

  # remove false positive for Java
  $$expr =~ s/^\s*package\b[^;\n]*[;\n]//sgm ;
  $$expr =~ s/^\s*import\b[^;\n]*[;\n]//sgm ;

	# neutralisation des operateur '*' de dereferencement
	#----------------------------------------------------
	# 1) neutralisation des '*' colles derriere un operateur d'indirection : . -> ou [. Ces operateur etant utilises pour splittes,
	#    les '*' en questions sont forcement en debut de token.
	$$expr =~ s/\[\s*\*/\[/sg;
	
	# 2) neutralisation des '*' suivant une '(', qui sont forcement des dereferencements.
	$$expr =~ s/\(\s*\*/\(/sg;
	
	# 3) neutralisation des '*' precedent une ')', qui sont forcement des dereferencements.
	$$expr =~ s/\*\s*\)/\)/sg;
	
	# 4) Les '*' qui restent sont des operateurs de calcul, ou bien des dereferencements colles a des operateurs de calcul.
	#    Dans tous ces cas, cela marque la fin d'une chaine d'indirections.


  #@tokens = split(/\.|->|\[/, $$expr);

  my $nb_DeepDeref = CountComplexDeref_InsideSubexpr($expr, 1);

  return $nb_DeepDeref;
}
1;
