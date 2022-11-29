#------------------------------------------------------------------------------#
#                         @ISOSCOPE 2008                                       #
#------------------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                          #
#               Adresse : TERSUD - Bat A                                       #
#                         5, AVENUE MARCEL DASSAULT                            #
#                         31500  TOULOUSE                                      #
#               SIRET   : 410 630 164 00037                                    #
#------------------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                                #
# l'Institut National de la Propriete Industrielle (lettre Soleau)             #
#------------------------------------------------------------------------------#

# Composant: Plugin
#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des protections des includes
#-------------------------------------------------------------------------------

package CountMissingIncludeProtections;
# les modules importes
use strict;
use warnings;
use Erreurs;
use TraceDetect;

# prototypes publics
sub CountMissingIncludeProtections($$$$);

# prototypes prives

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des protections des includes
#       #ifndef FICHIER_H
#       #define FICHIER_H
# Langages : C, C++
#-------------------------------------------------------------------------------
sub CountMissingIncludeProtections($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # Erreurs::LogInternalTraces
    my $b_fichier_h_ou_hpp = 0;
    if (($fichier =~ /\.h$/) || ($fichier =~ /\.hpp$/))
    {
	$b_fichier_h_ou_hpp = 1;
    }
    #
    my $base_filename = $fichier if ($b_TraceDetect); # Erreurs::LogInternalTraces
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # Erreurs::LogInternalTraces
    my $status = 0;
    my $debug = 0; # Erreurs::LogInternalTraces
    #
    my $trace_MissingIncludeProtections = '' if ($b_TraceDetect); # Erreurs::LogInternalTraces
    my $mnemo_MissingIncludeProtections = Ident::Alias_MissingIncludeProtections();
    my $nbr_MissingIncludeProtections = 0;
    #
    if (!defined $vue->{'text'})
    {
	assert(defined $vue->{'text'}) if ($b_assert); # Erreurs::LogInternalTraces
	$status |= Couples::counter_add($compteurs, $mnemo_MissingIncludeProtections, Erreurs::COMPTEUR_ERREUR_VALUE);
	$status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	return $status;
    }
    my $step = 0;
    #
    my $c = $vue->{'text'}; # pour avoir des instructions (code) et des macros !
    # Ecrabouiller commentaires et chaines.
    $c =~   s{
        	(
                    \"(\\.|[^\"]*)*\"	|
                    \'(\\.|[^\']*)*\'	|
                    //[^\n]*		|
                    /\*.*?\*/
		)
            }
            {
                my $match = $1;
                $match =~ s{\S+}{ }g;
                $match =~ s{\n}{\n}g;
                $match;
    	}gxse;
    #
    my $fic_out = $fichier . ".out" . $step if ($debug && $b_TraceDetect); # Erreurs::LogInternalTraces
    TraceDetect::TraceOutToFile($fic_out, $c) if ($debug && $b_TraceDetect); # Erreurs::LogInternalTraces
    # optimisation : recherche si qqchose autre que espace avant protection eventuelle
    if ($c =~ m{
                    (.*?)\#\s*ifndef                        
                }xms)
    {
	print STDERR "===> CAS 1\n"  if ($debug); # Erreurs::LogInternalTraces
	my $match_avant = $1;
	print STDERR "match_avant:$match_avant\n"  if ($debug); # Erreurs::LogInternalTraces
	my $match_avant2 = $match_avant;
	if ($match_avant2 =~ m/(\s*)[^\s]/g) # /g pour avoir pos
	{	# autre chose avant '#' donc pas de protection
	    my $avant = $1;
	    print STDERR "avant:$avant\n"  if ($debug); # Erreurs::LogInternalTraces
	    my $pos_avant2 = pos($match_avant2);
	    print STDERR "pos_avant2:$pos_avant2\n"  if ($debug); # Erreurs::LogInternalTraces
	    my $line_number = TraceDetect::CalcLineMatch($match_avant2, $pos_avant2) if ($b_TraceDetect); # Erreurs::LogInternalTraces
	    $nbr_MissingIncludeProtections = 1;
	    print STDERR "===> autre chose avant char diese\n" if ($debug); # Erreurs::LogInternalTraces
	    $match_avant2 =~ s/\n//g;
	    $match_avant2 =~ s/\s+//g;
	    my $trace_line = "$base_filename:$line_number:$match_avant2\n" if ($b_TraceDetect); # Erreurs::LogInternalTraces
	    print STDERR "$trace_line\n" if ($debug && $b_TraceDetect); # Erreurs::LogInternalTraces
	    $trace_MissingIncludeProtections .= $trace_line if ($b_TraceDetect); # Erreurs::LogInternalTraces
	}
    }
    if ($nbr_MissingIncludeProtections != 1)
    {
	if ($c =~ m{
			(                                   #1
			    \#\s*ifndef\s+(\w+)\s*\n        #2
			    \s*\#\s*define\s+((\w+)\s*\n)   #3 #4
			)
		    }gxms)
	{
	    print STDERR "===> CAS 2\n" if ($debug); # Erreurs::LogInternalTraces
	    my $match_all = $1;
	    my $match_ifndef_ident = $2;
	    my $match_define_ident_plus = $3; 
	    my $match_define_ident = $4; 
	    my $pos_c = pos($c);
	    #
	    my $line_number = 0; # Erreurs::LogInternalTraces
	    if ($match_ifndef_ident ne $match_define_ident)
	    {   # protection presente mais defaillante
		$nbr_MissingIncludeProtections = 1;
		my $len = length($match_define_ident_plus);
		$line_number = TraceDetect::CalcLineMatch($c, $pos_c-$len+1) if ($b_TraceDetect); # Erreurs::LogInternalTraces
		my $trace_line = "$base_filename:$line_number:$match_ifndef_ident:$match_define_ident\n" if ($b_TraceDetect); # Erreurs::LogInternalTraces
		print STDERR "$trace_line" if ($debug && $b_TraceDetect); # Erreurs::LogInternalTraces
		$trace_MissingIncludeProtections .= $trace_line if ($b_TraceDetect); # Erreurs::LogInternalTraces
	    }
	    else
	    {
	      print STDERR "===> protection OK\n"  if ($debug); # Erreurs::LogInternalTraces
	    }
	}
	else
	{	# pas de #
	    print STDERR "===> CAS 3\n"  if ($debug); # Erreurs::LogInternalTraces
	    $nbr_MissingIncludeProtections = 1;
	    my $trace_line = "$base_filename:0:::\n" if ($b_TraceDetect); # Erreurs::LogInternalTraces
	    print STDERR "$trace_line" if ($debug && $b_TraceDetect); # Erreurs::LogInternalTraces
	    $trace_MissingIncludeProtections .= $trace_line if ($b_TraceDetect); # Erreurs::LogInternalTraces
	}
    }
    if (not $b_fichier_h_ou_hpp)
    {
	$nbr_MissingIncludeProtections = 0;
	$trace_MissingIncludeProtections = ''  if ($b_TraceDetect); # traces_filter_line
    }
    #
    print STDERR "$mnemo_MissingIncludeProtections = $nbr_MissingIncludeProtections\n" if $debug; # Erreurs::LogInternalTraces
    TraceDetect::DumpTraceDetect($fichier, $mnemo_MissingIncludeProtections, $trace_MissingIncludeProtections, $options) if ($b_TraceDetect); # Erreurs::LogInternalTraces
    $status |= Couples::counter_add($compteurs, $mnemo_MissingIncludeProtections, $nbr_MissingIncludeProtections);
    #
    return $status;
}


1;
