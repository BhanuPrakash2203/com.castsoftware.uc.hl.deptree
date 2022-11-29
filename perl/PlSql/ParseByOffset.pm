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
#----------------------------------------------------------------------#
# DESCRIPTION: Composant pour fonctions/methodes/attributs en PL-SQL
#----------------------------------------------------------------------#


package PlSql::ParseByOffset;
# les modules importes
use strict;
use warnings;

use Erreurs;

use Carp::Assert; # traces_filter_line
use Couples;
use TraceDetect;


# prototypes publics
sub ParseByOffset($$$$);
sub Count_Methods($$$$);



#-------------------------------------------------------------------------------
# description: le module clean pl-sql
# cree un buffer en blanchissant certains passages, par exemple
# le code present entre deux end
#-------------------------------------------------------------------------------
sub _CountFunctionsMethodsAttributesFiltre($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $inputBuffer = $vue->{'code_without_directive'};
    
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0);          # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                  # traces_filter_line
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my $b_TraceIn = ((exists $options->{'--TraceIn'})? 1 : 0);                  # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                           # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                             # traces_filter_line
    my $debug = 0;                                                              # traces_filter_line
    
    my $status = 0;
    
    if (!defined $inputBuffer)
    {
	#assert(defined $inputBuffer) if ($b_assert); # traces_filter_line
	$status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	return $status;
    }
    
    my $step = 0;
    
    my $c = $inputBuffer; # code

    my $fic_out = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    TraceDetect::TraceOutToFile($fic_out, $c) if ($b_TraceDetect && $b_TraceIn); # traces_filter_line

    my $outputBuffer = $c; # code filtre
    $step++;
    print STDERR "#STEP:$step\n"  if ($debug); # traces_filter_line
    #############################################
    # effacer les sections de code cad BEGIN ... END (sauf BEGIN END)
    # pour ne pas matcher les appels de fonctions
    my @arr_match_pos_start1;
    my @arr_to_be_erased;
    while ($c =~ m{
		    (					#1	
			(\sPACKAGE\s+(BODY\s)?) 	#2  #3
			| (\sDECLARE\s) 	 	#4
			| (\sBEGIN\s) 	 		#5
			| (\sEND(.*?);)  	 	#6  #7
			| (\sfunction.*?(\s[ai]s|;))   	#8  #9
			| (\sprocedure.*?(\s[ai]s|;))  	#10 #11
		    )
                }gxmsi)
    {
	my $match_all = $1;
	my $match_package = $2;
	my $match_body = $3;
        my $match_declare = $4;
        my $match_begin = $5;
        my $match_end = $6;
	my $match_after_end = $7;
	my $match_function_header  = $8;  # et #9
	my $match_procedure_header = $10; # et #11
	
        my $pos_c = pos($c) - 1; # sur dernier caractere
	my $len = length($match_all);
	my $pos_start = $pos_c - $len + 2;
        my $line_number = 0;                                                        # traces_filter_line
        $line_number = TraceDetect::CalcLineMatch($c, $pos_start) if ($b_TraceDetect); # traces_filter_line
        print STDERR "=============\n" if ($debug);                                 # traces_filter_line
        print STDERR "line : $line_number\n" if ($debug);                           # traces_filter_line
        print STDERR "=match_all:$match_all\n" if ($debug);                         # traces_filter_line
        if (defined $match_package)
        {
	    if (not defined($match_body))
	    {	# les packages boby sont ignores car ils ont un begin end a l'interieur
		print STDERR "=> package interface\n" if ($debug); # traces_filter_line
		my $len = length($match_package);
		my $start = $pos_c - $len;
		my $value = "package:$start:$pos_c";
		push(@arr_match_pos_start1, $value);
	    }
	    else
	    {
		print STDERR "=> package body\n" if ($debug); # traces_filter_line
	    }
	}
        elsif (defined $match_declare)
        {
	    print STDERR "=> declare\n" if ($debug); # traces_filter_line
	    my $len = length($match_declare);
	    my $start = $pos_c - $len;
            my $value = "declare:$start:$pos_c";
            push(@arr_match_pos_start1, $value);
        }
        elsif (defined $match_begin)
        {
	    print STDERR "=> begin\n" if ($debug); # traces_filter_line
	    my $len = length($match_begin);
	    my $start = $pos_c - $len;
            my $value = "begin:$start:$pos_c";
            push(@arr_match_pos_start1, $value);
        }
	elsif (defined $match_end)
	{
	    if (not $match_after_end =~ /^\s*IF\s*$/)
	    {	# si ce n'est pas un 'END IF;'
		print STDERR "=> vrai end\n" if ($debug); # traces_filter_line
		my $len = length($match_end);
		my $start = $pos_c - $len;
		my $pos_apres_pt_virg = $pos_c + 1;
		my $value = "end:$start:$pos_apres_pt_virg";
		push(@arr_match_pos_start1, $value);
	    }
	}
	elsif (defined $match_function_header)
	{
    	    print STDERR "=> function header\n" if ($debug); # traces_filter_line
	    my $len = length($match_function_header);
	    my $start = $pos_c - $len;
	    my $pos_apres_pt_virg = $pos_c + 1;
            my $value = "functionprocedureheader:$start:$pos_apres_pt_virg";
            push(@arr_match_pos_start1, $value);
	}
	elsif (defined $match_procedure_header)
	{
    	    print STDERR "=> procedure header\n" if ($debug); # traces_filter_line
	    my $len = length($match_procedure_header);
	    my $start = $pos_c - $len;
	    my $pos_apres_pt_virg = $pos_c + 1;
            my $value = "functionprocedureheader:$start:$pos_apres_pt_virg";
            push(@arr_match_pos_start1, $value);
	}
    }
    my $nb = @arr_match_pos_start1;
    print STDERR "nb:$nb\n" if ($debug); # traces_filter_line
    for(my $i = 0; $i<($nb - 1); $i++)
    {	# deux par deux
	my $value_start_tok1 = $arr_match_pos_start1[$i];
	my ($inst1, $start_tok1, $end_tok1) = split(':', $value_start_tok1);
	
	my $value_end_tok2 = $arr_match_pos_start1[$i + 1];
	my ($inst2, $start_tok2, $end_tok2) = split(':', $value_end_tok2);
	
        my $line_number_start = TraceDetect::CalcLineMatch($c, $end_tok1) if ($b_TraceDetect);                       # traces_filter_line
	my $line_number_end = TraceDetect::CalcLineMatch($c, $start_tok2) if ($b_TraceDetect);                       # traces_filter_line
	my $nbr_lignes = $line_number_end - $line_number_start + 1  if ($b_TraceDetect);                           # traces_filter_line
	print STDERR "ITERATION ($i): $inst1->$inst2 : lignes $line_number_start-$line_number_end\n" if ($debug); # traces_filter_line
	if (   	   ($inst1 eq 'begin') && ($inst2 eq 'declare')
		|| ($inst1 eq 'begin') && ($inst2 eq 'end')
		|| ($inst1 eq 'begin') && ($inst2 eq 'functionprocedureheader')
		|| ($inst1 eq 'end') && ($inst2 eq 'end')
		|| ($inst1 eq 'end') && ($inst2 eq 'declare')
		|| ($inst1 eq 'functionprocedureheader') && ($inst2 eq 'functionprocedureheader')
	   )
	{   # effacement de fin tok1 a debut tok2
	    my $nbr_erase = $start_tok2 - $end_tok1 + 1;
	    print STDERR "$inst1->$inst2: ERASE $end_tok1-$start_tok2 : from $start_tok2, nb = $nbr_erase\n" if ($debug); # traces_filter_line
	    substr($outputBuffer, $end_tok1, $nbr_erase) =~ s/[^\n\s]/ /sg;
	    print STDERR "ERASE lignes : $line_number_start-$line_number_end : $nbr_lignes lignes\n" if ($debug);         # traces_filter_line
	}
	# on n'incremente pas si on a la sequence suivante :
	# - x end (code) end
	# - x end (code) declare
	if ($inst2 eq 'end')
	{
	    if (($i + 2) < $nb)
	    {	# il reste au moins un token
		my $value_next = $arr_match_pos_start1[$i + 2];
		my ($inst_next, $start_tok_next, $end_tok_next) = split(':', $value_next);
		if (($inst_next ne 'end') && ($inst_next ne 'declare'))
		{   # ce n'est pas un end qui suit, on incremente
		    $i++;
		    print STDERR "INC\n" if ($debug); # traces_filter_line
		}
	    }
	}
    }
    $fic_out = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    TraceDetect::TraceOutToFile($fic_out, $outputBuffer)  if ($b_TraceDetect && $b_TraceIn);            # traces_filter_line
    $step++;
    print STDERR "#STEP:$step\n"  if ($debug); # traces_filter_line
    #$c = $f;
    
    return ($status, $outputBuffer);
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Le module parseur PL-SQL
#-------------------------------------------------------------------------------
my $parser_plsql = 0;
use constant PARSE_UNDEFINED => $parser_plsql++;
use constant PARSE_PACKAGE_INTERFACE   => $parser_plsql++;
use constant PARSE_PACKAGE_BODY   => $parser_plsql++;
use constant PARSE_DECLARATION_FONCTION  => $parser_plsql++;
use constant PARSE_FORWARD_DECLARATION_FONCTION  => $parser_plsql++;
use constant PARSE_IMPLEMENTATION_FONCTION  => $parser_plsql++;
use constant PARSE_IMPLEMENTATION_FONCTION_LOCALE  => $parser_plsql++;
use constant PARSE_DECLARATION_PROCEDURE => $parser_plsql++;
use constant PARSE_FORWARD_DECLARATION_PROCEDURE => $parser_plsql++;
use constant PARSE_IMPLEMENTATION_PROCEDURE => $parser_plsql++;
use constant PARSE_IMPLEMENTATION_PROCEDURE_LOCALE => $parser_plsql++;

use constant SOURCE_HORS_PACKAGE => 0;
use constant SOURCE_PACKAGE_INTERFACE => 1;
use constant SOURCE_PACKAGE_BODY => 2;

sub _CountFunctionsMethodsAttributesParse($$$$$)
{
    my ($fichier, $vue, $compteurs, $options, $c) = @_;

    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0);          # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                           # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                             # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                  # traces_filter_line
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my $debug = 0;                                                              # traces_filter_line
    my $debug2 = ((exists $options->{'--FMAdebug'})? 1 : 0);                    # traces_filter_line

    my @parsed_code; # contient des referecnces sur des hash
    
    my $status = 0;
    
    print STDERR "##############################################\n" if ($debug2); # traces_filter_line

    my $type_source = SOURCE_HORS_PACKAGE;
    my $scope_package = '';
    my $b_stack_size_error = 0;
    my $uid = 1;
    my $package_begin_end_scope_level = 0;
# FIXME: dans le cas ou le fichier ne contient ni is as declare exception ; 
# FIXME: cette boucle ne se termine pas avant longtemps!
    while ($c =~    m{
                            (\s*)                   	#1
                            |
                            (                       	#2
                                (begin\s)      		#3    (debut de chaine)
				| (end(\s*|\s\w+\s*);)	#4 #5 (debut de chaine)
				| (.*?)             	#6
				  (                 	#7
				    (\sis\s)	    	#8 package interface OU pakage body OU fonction impl OU procedure impl OU decl cursor
				    | (\sas\s)	    	#9 package interface OU pakage body OU fonction impl OU procedure impl OU requete sql
				    | (\sdeclare\s)	#10
				    | (\sexception\s)	#11
				    | (;)           	#12 inst OU decl OU end OU end if
				  )
			    )
                                | (?:[^;]*)             # garbage
			}gxmis)
    {
        my $match_spaces = $1;
        my $match_all = $2;
        my $match_begin = $3;
	my $match_end = $4; # et 5
        my $match_avant = $6;
	my $match_after = $7;
        my $match_is = $8;
        my $match_as = $9;
        my $match_declare = $10;
        my $match_exception = $11;
        my $match_pt_virgule = $12;
	
        if (defined $match_spaces)
        {   next;   }
	if (defined $match_begin)
	{
	    $match_avant = $match_begin;
	}
	elsif (defined $match_end)
	{
	    $match_avant = $match_end;
	}
        # nettoyage
	my $match_avant_multiline = $match_avant;
	$match_avant =~ s/\s+/ /g;
	$match_avant =~ s/\s+$//;
	$match_avant =~ s/\n/ /g;
        
        my $pos_c_B0 = pos($c) - 1;
        print STDERR "=============\n" if ($debug2);         # traces_filter_line
        print STDERR "=match_all:$match_all\n" if ($debug2); # traces_filter_line
        my $len_match_all = length($match_all);
        my $len_avant = length($match_avant);
        my $start_pos_B0 = $pos_c_B0-$len_match_all + 1;
#        print STDERR "start_pos_B0:$start_pos_B0\n" if ($debug);                      # traces_filter_line
        my $line_number = 0;                                                           # traces_filter_line
        $line_number = TraceDetect::CalcLineMatch($c, $start_pos_B0) if ($b_TraceDetect); # traces_filter_line
        print STDERR "line_number:$line_number\n" if($b_TraceDetect && $debug2);       # traces_filter_line
        
        my %hash_item;
	$hash_item{'uid'} = $uid++;
        $hash_item{'item'} = $match_avant;
        $hash_item{'line_number'} = $line_number if ($b_TraceDetect);                     # traces_filter_line
	$hash_item{'scope_package'} = $scope_package;
        
	if (defined $match_begin)
	{
	    my $new_val = $package_begin_end_scope_level + 1;
	    print STDERR "=> begin : pile $package_begin_end_scope_level->$new_val \n" if ($debug); # traces_filter_line
	    $package_begin_end_scope_level++;
	}
	elsif (defined $match_end)
	{
	    my $new_val = $package_begin_end_scope_level - 1;
	    print STDERR "=> end : pile $package_begin_end_scope_level->$new_val \n" if ($debug); # traces_filter_line
	    $package_begin_end_scope_level--;
	    if ($package_begin_end_scope_level == 0)
	    {
		$scope_package = '';
		print STDERR "=> package_begin_end_scope_level = $package_begin_end_scope_level \n" if ($debug); # traces_filter_line
	    }
	}
	elsif ((defined $match_is) || (defined $match_as))
	{
    	    # cas qui peuvent etre IS ou AS
	    print STDERR "=> is ou as \n" if ($debug); # traces_filter_line
	    if ($match_avant =~ /\spackage\s+body\s+(\w+)/i)
	    {
		my $match_package_name = $1;
		$package_begin_end_scope_level++;
		print STDERR "=> package body\n" if ($debug); # traces_filter_line
		$type_source = SOURCE_PACKAGE_BODY;
		$scope_package = $match_package_name;
	    }
	    elsif ($match_avant =~ /\spackage\s+(\w+)/i)
	    {
		my $match_package_name = $1;
		print STDERR "=> package interface\n" if ($debug); # traces_filter_line
		$package_begin_end_scope_level++;
		$type_source = SOURCE_PACKAGE_INTERFACE;
		$scope_package = $match_package_name;
	    }
	    elsif ($match_avant =~ /^function\s/i)
	    {
		if ($package_begin_end_scope_level > 1)
		{   # fonction locale
		    print STDERR "=> impl fonction locale\n" if ($debug); # traces_filter_line
		    push(@parsed_code, [PARSE_IMPLEMENTATION_FONCTION_LOCALE, \%hash_item]);
		}
		else
		{
		    print STDERR "=> impl fonction\n" if ($debug); # traces_filter_line
		    push(@parsed_code, [PARSE_IMPLEMENTATION_FONCTION, \%hash_item]);
		}
	    }
	    elsif ($match_avant =~ /^procedure\s/i)
	    {
		if ($package_begin_end_scope_level > 1)
		{   # fonction locale
		    print STDERR "=> impl procedure locale\n" if ($debug); # traces_filter_line
		    push(@parsed_code, [PARSE_IMPLEMENTATION_PROCEDURE_LOCALE, \%hash_item]);
		}
		else
		{
		    print STDERR "=> impl procedure\n" if ($debug); # traces_filter_line
		    push(@parsed_code, [PARSE_IMPLEMENTATION_PROCEDURE, \%hash_item]);
		}
	    }
	}
        elsif (defined $match_pt_virgule)
        {
            print STDERR "=> point virgule\n" if ($debug); # traces_filter_line
	    if ($type_source == SOURCE_HORS_PACKAGE)
	    {
		print STDERR "type_source: SOURCE_HORS_PACKAGE\n" if ($debug); # traces_filter_line
	    }
	    elsif ($type_source == SOURCE_PACKAGE_INTERFACE)
	    {	
		print STDERR "type_source: SOURCE_PACKAGE_INTERFACE\n" if ($debug); # traces_filter_line
		if ($match_avant =~ /^function\s/i)
		{
		    print STDERR "=> decl fonction\n" if ($debug); # traces_filter_line
		    push(@parsed_code, [PARSE_DECLARATION_FONCTION, \%hash_item]);
		}
		elsif ($match_avant =~ /^procedure\s/i)
		{
		    print STDERR "=> decl procedure\n" if ($debug); # traces_filter_line
		    push(@parsed_code, [PARSE_DECLARATION_PROCEDURE, \%hash_item]);
		}
	    }
	    elsif ($type_source == SOURCE_PACKAGE_BODY)
	    {	# les forward declarations dans le packages body
		print STDERR "type_source: SOURCE_PACKAGE_BODY\n" if ($debug); # traces_filter_line
		if ($match_avant =~ /^function\s/i)
		{
		    print STDERR "=> forward decl fonction\n" if ($debug); # traces_filter_line
		    push(@parsed_code, [PARSE_FORWARD_DECLARATION_FONCTION, \%hash_item]);
		}
		elsif ($match_avant =~ /^procedure\s/i)
		{
		    print STDERR "=> forward decl procedure\n" if ($debug); # traces_filter_line
		    push(@parsed_code, [PARSE_FORWARD_DECLARATION_PROCEDURE, \%hash_item]);
		}
	    }
        }
    }
    if ($package_begin_end_scope_level != 0)
    {
#            $b_stack_size_error = 1;
            print STDERR "la pile devrait etre vide ($package_begin_end_scope_level)\n" if ($b_TraceInconsistent); # traces_filter_line
            assert($package_begin_end_scope_level!=0, 'la pile devrait etre vide') if ($b_assert);                 # traces_filter_line
    }
    
    if (not $b_stack_size_error)
    {	$vue->{'parsed_code'} = \@parsed_code;	}
    else
    {
        $status |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE;
    }
    
    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: 
# Module de comptage du nombre de declaration de fonctions/procedures
# Module de comptage du nombre d'implementation de fonctions/procedures
# Module de comptage du nombre de fonctions/methodes publiques
#-------------------------------------------------------------------------------
sub Count_Methods($$$$)
{
#    my ($fichier, $compteurs, $options, $error) = @_;
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0);                  # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                                   # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                                     # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                          # traces_filter_line
    my $debug = 0;                                                                      # traces_filter_line
    my $langage = $$compteurs{'Dat_Language'};
    my $status = 0;
    #  methodes
    my $trace_detect_methods = '' if ($b_TraceDetect);                                  # traces_filter_line
    
    my $mnemo_FunctionImplementations = Ident::Alias_FunctionImplementations_old();
    my $nbr_FunctionImplementations = 0;
    
    my $mnemo_ProcedureImplementations = Ident::Alias_ProcedureImplementations_old();
    my $nbr_ProcedureImplementations = 0;
    
    my $mnemo_FunctionDeclarations = Ident::Alias_FunctionDeclarations_old();
    my $nbr_FunctionDeclarations = 0;
    
    my $mnemo_ProcedureDeclarations = Ident::Alias_ProcedureDeclarations_old();
    my $nbr_ProcedureDeclarations = 0;
    
    my $trace_detect_PublicFonctionsProcedures = '' if ($b_TraceDetect);              # traces_filter_line
    my $mnemo_PublicFonctionsProcedures = Ident::Alias_PublicFonctionsProcedures();
    my $nbr_PublicFonctionsProcedures = 0;
    
    if (!defined $vue->{'parsed_code'})
    {
        assert(defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add($compteurs, $mnemo_FunctionImplementations, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_ProcedureImplementations, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_FunctionDeclarations, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_ProcedureDeclarations, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_PublicFonctionsProcedures, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }
    
    my @parsed_code= @{$vue->{'parsed_code'}};
    
    foreach my $item (@parsed_code)
    {
	my $kind = $item->[0];
	my $hash_ref = $item->[1];
	my %hash_item = %$hash_ref;
	assert(exists $hash_item{'uid'}); # traces_filter_line
	assert(exists $hash_item{'scope_package'}); # traces_filter_line
	my $uid = $hash_item{'uid'};
	if (($kind == PARSE_DECLARATION_FONCTION)
	    || ($kind == PARSE_DECLARATION_PROCEDURE))
	{
	    my $line_number = 0;                                          # traces_filter_line
	    $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
	    my $item = $hash_item{'item'};
	    print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
	    print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
	    print STDERR "$item\n" if ($debug);                           # traces_filter_line
	    my $scope_package = $hash_item{'scope_package'};
	    
	    my $name;
	    if ($item =~ /(function|procedure)\s+(\w+)/i)
	    {
		$name = $2;
	    }
	    my $tag;
	    if ($kind == PARSE_DECLARATION_FONCTION)
	    {
		$nbr_FunctionDeclarations++;
		$tag = 'DF';
		$nbr_PublicFonctionsProcedures++;
	    }
	    elsif ($kind == PARSE_DECLARATION_PROCEDURE)
	    {
		$nbr_ProcedureDeclarations++;
		$tag = 'DP';
		$nbr_PublicFonctionsProcedures++;
	    }
	    
	    my $trace_line = "$base_filename:$line_number:$tag:[$scope_package]:$item\n" if ($b_TraceDetect); # traces_filter_line
	    $trace_detect_methods .= $trace_line if ($b_TraceDetect); # traces_filter_line
	    
	    $trace_detect_PublicFonctionsProcedures .= "$base_filename:$line_number:$scope_package.$name:\n" if ($b_TraceDetect); # traces_filter_line
	}
	elsif (($kind == PARSE_IMPLEMENTATION_FONCTION)
	       || ($kind == PARSE_IMPLEMENTATION_PROCEDURE)
	       || ($kind == PARSE_IMPLEMENTATION_FONCTION_LOCALE)
	       || ($kind == PARSE_IMPLEMENTATION_PROCEDURE_LOCALE)
	       || ($kind == PARSE_FORWARD_DECLARATION_FONCTION)
	       || ($kind == PARSE_FORWARD_DECLARATION_PROCEDURE))
	{
	    my $line_number = 0;                                          # traces_filter_line
	    $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
	    my $item = $hash_item{'item'};
	    print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
	    print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
	    print STDERR "$item\n" if ($debug);                           # traces_filter_line
	    my $scope_package = $hash_item{'scope_package'};
	    
	    my $tag;
	    if ($kind == PARSE_IMPLEMENTATION_FONCTION)
	    {
		$nbr_FunctionImplementations++;
		$tag = 'IF';
	    }
	    elsif ($kind == PARSE_IMPLEMENTATION_PROCEDURE)
	    {
		$nbr_ProcedureImplementations++;
		$tag = 'IP';
	    }
	    elsif ($kind == PARSE_IMPLEMENTATION_FONCTION_LOCALE)
	    {
		$tag = 'IFL';
	    }
	    elsif ($kind == PARSE_IMPLEMENTATION_PROCEDURE_LOCALE)
	    {
		$tag = 'IPL';
	    }
	    elsif ($kind == PARSE_FORWARD_DECLARATION_FONCTION)
	    {
		$tag = 'IPFD';
	    }
	    elsif ($kind == PARSE_FORWARD_DECLARATION_PROCEDURE)
	    {
		$tag = 'IPPD';
	    }
	    my $trace_line = "$base_filename:$line_number:$tag:[$scope_package]:$item\n" if ($b_TraceDetect); # traces_filter_line
	    $trace_detect_methods .= $trace_line if ($b_TraceDetect);                                         # traces_filter_line
	}
    }
    
    print STDERR "$mnemo_FunctionDeclarations = $nbr_FunctionDeclarations\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_FunctionDeclarations, $trace_detect_methods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_FunctionDeclarations, $nbr_FunctionDeclarations);
    
    print STDERR "$mnemo_ProcedureDeclarations = $nbr_ProcedureDeclarations\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_ProcedureDeclarations, $trace_detect_methods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_ProcedureDeclarations, $nbr_ProcedureDeclarations);
    
    print STDERR "$mnemo_FunctionImplementations = nbr_FunctionImplementations\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_FunctionImplementations, $trace_detect_methods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_FunctionImplementations, $nbr_FunctionImplementations);
    
    print STDERR "$mnemo_ProcedureImplementations = $nbr_ProcedureImplementations\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_ProcedureImplementations, $trace_detect_methods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_ProcedureImplementations, $nbr_ProcedureImplementations);
    
    print STDERR "$mnemo_PublicFonctionsProcedures = $nbr_PublicFonctionsProcedures\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_PublicFonctionsProcedures, $trace_detect_PublicFonctionsProcedures, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_PublicFonctionsProcedures, $nbr_PublicFonctionsProcedures);
    
    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: 
# Module de comptage du nombre de parametres total
# (declaration et implementation)
# Module de comptage du nombre de methodes avec trop de parametres
# (plus de 7) (declaration et implementation)
# Module de comptage du nombre de parametres OUT pour les fonctions
# Module de comptage des parametres qui sont implicitement IN
# Les comptages sont realises dans le body uniquement
#-------------------------------------------------------------------------------
use constant SEUIL_MAX_NB_PARAM => 7;
sub Count_Parameters($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # methodes avec trop de parametres
    my $nbr_WithTooMuchParametersMethods = 0;
    my $mnemo_WithTooMuchParametersMethods = Ident::Alias_WithTooMuchParametersMethods_old();
    my $trace_detect_WithTooMuchParametersMethods = '' if ($b_TraceDetect); # traces_filter_line
    # nombre total de parametres
    my $nbr_TotalParameters = 0;
    my $mnemo_TotalParameters = Ident::Alias_TotalParameters();
    my $trace_detect_TotalParameters = '' if ($b_TraceDetect); # traces_filter_line
    
    my $nbr_FunctionOutParameters = 0;
    my $mnemo_FunctionOutParameters = Ident::Alias_FunctionOutParameters();
    my $trace_detect_FunctionOutParameters = '' if ($b_TraceDetect); # traces_filter_line
    
    my $nbr_ImplicitInParameters = 0;
    my $mnemo_ImplicitInParameters = Ident::Alias_ImplicitInParameters();
    my $trace_detect_ImplicitInParameters = '' if ($b_TraceDetect); # traces_filter_line
    
    my $nbr_ZeroParameterProcedures = 0;
    my $mnemo_ZeroParameterProcedures = Ident::Alias_ZeroParameterProcedures();
    my $trace_detect_ZeroParameterProcedures = '' if ($b_TraceDetect); # traces_filter_line
    #Nbr_ZeroParameterProcedures
    
    if (!defined $vue->{'parsed_code'})
    {
        assert(defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add($compteurs, $mnemo_WithTooMuchParametersMethods, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_TotalParameters, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_FunctionOutParameters, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_ImplicitInParameters, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_ZeroParameterProcedures, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }
    
    my @parsed_code= @{$vue->{'parsed_code'}};
    
    foreach my $item (@parsed_code)
    {
        my $kind = $item->[0];
        my $hash_ref = $item->[1];
        my %hash_item = %$hash_ref;
	assert(exists $hash_item{'uid'}); # traces_filter_line
	assert(exists $hash_item{'scope_package'}); # traces_filter_line
        my $nb_param = 0;
        my @arr_params;
        if (($kind == PARSE_IMPLEMENTATION_FONCTION)
         || ($kind == PARSE_IMPLEMENTATION_PROCEDURE)
         || ($kind == PARSE_IMPLEMENTATION_FONCTION_LOCALE)
         || ($kind == PARSE_IMPLEMENTATION_PROCEDURE_LOCALE))
        {
            my $line_number = 0; # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
            print STDERR "$item\n" if ($debug); # traces_filter_line
            if ($item =~ /\((.*)\)/)
            {	# il y a un ou des parametres
		# comptages des parametres
                my $match_param = $1;
                if ($match_param =~ /^\s*$/)
                {   # pas de parametres(normalement ce cas de doit pas arriver en PL-SQL
                    $nb_param = 0;
                }
                else
                {   # au moins un parametre
                    @arr_params = split(',', $match_param);
                    print STDERR "arr_params:@arr_params\n" if ($debug); # traces_filter_line
                    $nb_param = @arr_params;
                }
		# comptage des parametres OUT pour les fonctions
		if (($kind == PARSE_IMPLEMENTATION_FONCTION)
		    || ($kind == PARSE_IMPLEMENTATION_FONCTION_LOCALE))
		{
		    my $nb_out = () = $item =~ /\sOUT\s/ig;
		    if ($nb_out != 0)
		    {
			$nbr_FunctionOutParameters += $nb_out;
			$trace_detect_FunctionOutParameters .= "$base_filename:$line_number:$item:$nb_out\n" if ($b_TraceDetect); # traces_filter_line
		    }
		}
		# comptage des parametres implicitements IN
		my $nb_implicit_in = 0;
		my $param_number = 0;
		foreach my $param (@arr_params)
		{
		    $param_number++; # traces_filter_line
		    if ((not $param =~ /\sOUT\s/i) and (not $param =~ /\sIN\s/i))
		    {
			$nb_implicit_in++; # traces_filter_line
			$trace_detect_ImplicitInParameters .= "$base_filename:$line_number:$item:param n°$param_number\n" if ($b_TraceDetect); # traces_filter_line
		    }
		}
		if ($nb_implicit_in != 0)
		{
		    $nbr_ImplicitInParameters += $nb_implicit_in;
		}
            }
	    else
	    {	# il n'y a pas de parametres
		if (($kind == PARSE_IMPLEMENTATION_FONCTION_LOCALE)
		    || ($kind == PARSE_IMPLEMENTATION_PROCEDURE_LOCALE))
		{
		    $nbr_ZeroParameterProcedures++;
		    $trace_detect_ZeroParameterProcedures .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
		}
	    }
	    # comptages des fonctions/procedures avec trop de parametres
            print STDERR "nb_param : $nb_param \n" if ($debug); # traces_filter_line
            if ($nb_param > SEUIL_MAX_NB_PARAM)
            {
                $nbr_WithTooMuchParametersMethods++;
                $trace_detect_WithTooMuchParametersMethods .= "$base_filename:$line_number:$item:$nb_param\n" if ($b_TraceDetect); # traces_filter_line
            }
            $nbr_TotalParameters += $nb_param;
            $trace_detect_TotalParameters .= "$base_filename:$line_number:$item:$nb_param\n" if ($b_TraceDetect); # traces_filter_line
        }
    }
    #
    print STDERR "$mnemo_WithTooMuchParametersMethods = $nbr_WithTooMuchParametersMethods\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_WithTooMuchParametersMethods, $trace_detect_WithTooMuchParametersMethods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_WithTooMuchParametersMethods, $nbr_WithTooMuchParametersMethods);
    
    print STDERR "$mnemo_TotalParameters = $nbr_TotalParameters\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_TotalParameters, $trace_detect_TotalParameters, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_TotalParameters, $nbr_TotalParameters);
    
    print STDERR "$mnemo_FunctionOutParameters = $nbr_FunctionOutParameters\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_FunctionOutParameters, $trace_detect_FunctionOutParameters, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_FunctionOutParameters, $nbr_FunctionOutParameters);
    
    print STDERR "$mnemo_ImplicitInParameters = $nbr_ImplicitInParameters\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_ImplicitInParameters, $trace_detect_ImplicitInParameters, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_ImplicitInParameters, $nbr_ImplicitInParameters);
    
    print STDERR "$mnemo_ZeroParameterProcedures = $nbr_ZeroParameterProcedures\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_ZeroParameterProcedures, $trace_detect_ZeroParameterProcedures, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_ZeroParameterProcedures, $nbr_ZeroParameterProcedures);
    
    return $status;
}

#-------------------------------------------------------------------------------
# Module de comptage du nombre d'utilisations de fonctions ou de variables externes
# ils ont la forme :
# -NOM_PACKAGE.nom_fonction(
# -NOM_PACKAGE.nom_fonction
# -NOM_PACKAGE.nom_procedure(
# -NOM_PACKAGE.attribut_public
# Dans les requetes SQL, les alias de table ne doivent pas etre pris en compte
# Limitation : ne traite pas les records
#-------------------------------------------------------------------------------
sub CountExternalReferences($$$$)
{
    #FIXME:
    return 0;
    #########

    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0);          # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                  # traces_filter_line
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my $b_TraceIn = ((exists $options->{'--TraceIn'})? 1 : 0);                  # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                           # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                             # traces_filter_line
    my $trace_detect = '';                                                      # traces_filter_line
    my $debug = 0;                                                              # traces_filter_line
    
    my $status = 0;
    my $n = 0;
    my $mnemo = Ident::Alias_ExternalReferences();
    
    my $c = $vue->{'code'}; # code
    my $f = $c;
    # supprimer les alias de table comme :
    #  SELECT A1.region_name REGION, SUM(A2.Sales) SALES
    #  FROM Geography A1, Store_Information A2
    #  WHERE A1.store_name = A2.store_name
    #  GROUP BY A1.region_name
    while ($c =~ m{
		    (							#1	
			\s((select|insert|update|delete)\s.*?;) 	#2 #3
		    )
	    }gxmsi)
    {
	my $match_all = $1;
	my $match_requete_sql = $2;
	
        print STDERR "match_requete_sql : $match_requete_sql\n" if ($debug); # traces_filter_line
	my $pos_c = pos($c) - 1; # sur dernier caractere
	my $len = length($match_requete_sql);
	my $pos_start = $pos_c - $len + 1;
	
	# extraction des alias
	my @arr_alias;
	while ($match_requete_sql =~ m{
			(				#1	
			    from\s(.*?)\swhere\s	#2
			)
		}gxmsi)
	{
	    my $match_all = $1;
	    my $match_from = $2;
	    print STDERR "match_from : $match_from\n" if ($debug); # traces_filter_line
	    my @arr_tables = split(',', $match_from);
	    my $nb = @arr_tables;
	    if ($nb >1)
	    {
		foreach my $table(@arr_tables)
		{
		    my @couple = split(' ', $table);
		    my $nom_table = $couple[0];
		    my $nom_alias = $couple[1];
		    print STDERR "ALIAS : $nom_table-$nom_alias\n" if ($debug); # traces_filter_line
		    push(@arr_alias, $nom_alias);
		}
	    }
	}
	# ecrase les alias
	foreach my $alias(@arr_alias)
	{
	    my $pattern = "\\b$alias\\.";
	    print STDERR "pattern:$pattern\n" if ($debug); # traces_filter_line;
	    substr($f, $pos_start, $len) =~ s{($pattern)}
					    {
						my $match = $1;
						my $len = length($match);
						" " x $len;
					    }gxem;
	    my $apres = substr($f, $pos_start, $len);
	    print STDERR "apres substitution:$apres\n" if ($debug); # traces_filter_line;
	}
    }
    $c = $f;
    my $fic_out = $fichier . ".apres_sup_alias"  if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    TraceDetect::TraceOutToFile($fic_out, $c) if ($b_TraceDetect && $b_TraceIn);       # traces_filter_line
    
    while ($c =~ m{
                    (\b\w+\.\w+\b)
		}gxms)
    {
        my $match = $1;
        $n++;
        my $line_number = TraceDetect::CalcLineMatch($c, pos($c)) if ($b_TraceDetect); # traces_filter_line
        $trace_detect .= "$base_filename:$line_number:$match\n" if($b_TraceDetect); # traces_filter_line
    }
    
    print STDERR "$mnemo = $n \n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo , $n );
    
    return $status;
}


# description: le module parse pl-sql (point d'entree)
sub ParseByOffset($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my ($status, $c) = _CountFunctionsMethodsAttributesFiltre($fichier, $vue, $couples, $options);
    $status |= _CountFunctionsMethodsAttributesParse($fichier, $vue, $couples, $options, $c);
    
    return $status;
}


1;


