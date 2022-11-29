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

# Composant: Framework
#------------------------------------------------------------------------------#
# DESCRIPTION: Ce paquetage fournit des fonctionnalites pour
# une separation du code et des commentaires d'un source
#------------------------------------------------------------------------------#


package StripUtils;
# FIXME: voir localTrace...  use strict;

# les modules importes
use warnings ;
use Erreurs;

require Exporter;
use base qw/Exporter/;

# prototypes publics
sub configureLocalTraces($$);            # traces_filter_line
sub ErrStripError(;$$$);
sub localTraceOnStderr($$);              # traces_filter_line
sub localTraceNop;                       # traces_filter_line
sub garde_newlines($);
sub warningTrace($$);                    # traces_filter_line
sub StringStore($$;$);

# prototypes prives
sub localTraceTabOnStderr($$);           # traces_filter_line
sub init($$);                            # traces_filter_line
sub dumpVueStrings($$);                  # traces_filter_line


# Public, encouraged API is exported by default

our @EXPORT = qw(
    ErrStripError
    configureLocalTraces
    localTraceOnStderr
    localTraceNop
);
# ErrStripError configureLocalTraces localTraceOnStderr localTraceTab localTraceNop

our @FB_FLAGS  = qw();
our @FB_CONSTS = qw();

our @EXPORT_OK =
  (
   qw(
      ErrStripError
      configureLocalTraces
      localTraceOnStderr
      localTraceNop
      garde_newlines
      warningTrace
      StringStore
      dumpVueStrings
     ),
  );
# ErrStripError configureLocalTraces localTraceOnStderr localTraceTab localTraceNop

our %EXPORT_TAGS =
    (
     'all'          =>  [ @EXPORT, @EXPORT_OK ],
    );


#-------------------------------------------------------------------------------
# DESCRIPTION: Renvoie un code d'erreur lorsque l'on ne sait pas faire le Strip.
#-------------------------------------------------------------------------------
sub ErrStripError(;$$$)
{
  my ($isAbort, $value, $couples) = @_;
  my $status = 0;
  if ( (defined $isAbort) and ( $isAbort eq 1 ) )
  {
    # Cas d'une erreur fatale
    $status |= Erreurs::FatalError ($value, $couples, 'ErrStripError');
  }
  else
  {
    # Cas d'un avertissement
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP;
  }
  return $status;
}


# traces_filter_start

my $traceOptions;


#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction de configuration de ce module pour les traces.
#-------------------------------------------------------------------------------
sub configureLocalTraces($$)
{
  my ($module, $options) = @_;
  $traceOptions=$options;
  init ( $module, exists $traceOptions->{'--strip_trace'} );
  #$traceOptions=$_;
  #print STDERR join ( "\n", keys ( %{$traceOptions} ) );
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction pour les traces de debug.
#-------------------------------------------------------------------------------
sub localTraceNop
{
  return ;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Traces sur la sortie STDERR.
#-------------------------------------------------------------------------------
sub localTraceOnStderr($$)
{
  my ($type, $message) = @_;

  if ( (not defined $type) )
  {
    #print STDERR 'localTrace:' . $type . " ... \n" ;
    ;
  }
  else
  {
    #print STDERR 'localTrace:' .$type . " ... " . $traceOptions->{'--'.$type } . ' ... ' . ( exists $traceOptions->{'--'.$type }) ."\n";
    ;
  }

  if (not defined $type)
  {
    print STDERR 'DEBUG: ' . $message ;
  }
  elsif ( ( defined $type) and (exists $traceOptions->{'--'.$type }) )
  {
    print STDERR $type . ': ' . $message ;
  }
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction de trace prenant comme entree un tableau.
#-------------------------------------------------------------------------------
sub localTraceTabOnStderr($$)
{
  my ($type, $refArrayMessage) = @_;

  if ( (not defined $type) )
  {
    #print STDERR 'localTrace:' . $type . " ... \n" ;
    ;
  }
  else
  {
    #print STDERR 'localTrace:' .$type . " ... " . $traceOptions->{'--'.$type } . ' ... ' . ( exists $traceOptions->{'--'.$type }) ."\n";
    ;
  }

  if (not defined $type)
  {
    print STDERR 'DEBUG: ' . join ( '' , @{$refArrayMessage} );
  }
  elsif ( ( defined $type) and (exists $traceOptions->{'--'.$type }) )
  {
    print STDERR $type . ': ' . join ( '' , @{$refArrayMessage} );
  }
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Initialisation du module appelant
#-------------------------------------------------------------------------------
sub init($$)
{
  my ($module, $enable) = @_;
  if ($enable)
  {
    # Pour debugger, utilisation de pointeurs de fonction sur le modele Carp::Assert
    # necessite la desactivation de use strict:
    # Can't use string ("StripJava::localTrace") as a symbol ref while "strict refs
    *{$module.'::localTrace'} = \&localTraceOnStderr;
    *{$module.'::localTraceTab'} = \&localTraceTabOnStderr;
  }
  else
  {
    *{$module.'::localTrace'} = \&localTraceNop;
    *{$module.'::localTraceTab'} = \&localTraceNop;
  }
}



#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction pour les traces avertissant d'une erreur
#-------------------------------------------------------------------------------
sub warningTrace($$)
{
  my (undef, $message) = @_;
  print STDERR $message ;
}

# traces_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction de gestion des literaux detectes dans des codes sources
#-------------------------------------------------------------------------------
sub StringStore($$;$)
{
  my ($context, $string_buffer, $tag)=@_;

  if (!defined $tag) {
    $tag = 'CHAINE_';
  }

  #localTrace undef , join ( ',' , keys ( %{$context} ) ) . "\n" ; # traces_filter_line
  my ($id, $nb) = ($context->{'nb_distinct_strings'}, 1);
  if (defined $context->{'strings_counts'}->{$string_buffer} )
  {
    # Si la chaine a deja ete rencontree, on recupere son id et
    # on incremente son nombre d'occurence.
    ($id, $nb) = @{$context->{'strings_counts'}->{$string_buffer}};
    $nb ++;
  }
  else
  {
    # Si il s'agit de la premiere occurence de la chaine, on
    # incremente de nombre total de chaines distinctes, et l'id
    # de la chaine prend cette valeur.
    $context->{'nb_distinct_strings'}++;
    $id = $context->{'nb_distinct_strings'};
  }

  # memorisation des infos relatives a la chaine.
  $context->{'strings_counts'}->{$string_buffer} = [ $id, $nb ];

  # On construit la cle d'acces a la valeur de la chaine.
  my $string_id = $tag.$id;
  if ( ! defined $context->{'strings_values'}->{$string_id})
  {
    $context->{'strings_values'}->{$string_id} = $string_buffer ;
  }
  return $string_id ;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Create an 'agglo' view from the MixView.
#
# The MixBloc view should have only /*..*/ comments and no multiline comments.
#-------------------------------------------------------------------------------

sub agglomerate_C_Comments($$) {
  my $Mix = shift;
  my $agglo = shift;

  $$agglo = "";

  while ( $$Mix =~ /(\/\*(?:[\*][^\/\n]|[^\*\n])*\*\/)|((?:[\/](?:[^\*\n]|\Z)|[^\/\n]){1,32000})|(\n)/sg ) {
    if (defined $1) {
      # A comment ...
      $$agglo .= 'C';

    }
    elsif (defined $2) {
      # A piece of program.
      if ( $2 =~ /\S/s ) {
        $$agglo .= 'P';
      }
    }
    else {
      # A new line.
      $$agglo .= "\n";
    }
  }
	
	$$agglo =~ s/P+/P/g; # if a case of length limit 32000 is exceeded ($2)

}

#-------------------------------------------------------------------------------
# DESCRIPTION: Creation d'un buffer de remplacement contenant autant de retours a la ligne.
#-------------------------------------------------------------------------------
sub garde_newlines($)
{
  my ($b) =@_;
  my $resultat = '';

# traces_filter_start

  # Note sur les performances
  # L'environnement de test semble faire une execution par fichier,
  # pour des petits fichiers.
  # Le temps d'execution de l'environnement de test correspond donc plutot
  # au temps de compilation.
  # L'IHM fait (pour le moment) une analyse multifichiers.
  # De plus lex.yy.cpp est un fichier de 11 Megas.
  # Il s'agit donc de deux cas extremement oppose.
  # Le second correspond sans-doute mieux au test d'une grosse application.

  # Methode 1:
  # La version originale:
  # Sur environnement de test: 136 s. linux/13 mars (Autres applis lancees)
  # Sur environnement de test: 117 s. linux/13 mars
  # Sur IHM linux avec lex.yy.cpp  linux/13 mars :
  # StripJava  :14.954374   :14.936670   :2   :separer_code_commentaire_chaine
  # StripJava  :20.958307   :6.003933    :3   :SupprimeMacro3
  # Rejeu:
  # StripJava  :14.986843   :14.968924   :2   :separer_code_commentaire_chaine
  # StripJava  :20.463580   :5.476737    :3   :SupprimeMacro3
  if (0) # Cette methode est franchement la plus lente des 4.
  {
    $b =~ s/[^\n]//gsm ; # FIXME:  consomme 10 secondes sur 28.
    $resultat = $b;
  }


  # Methode 2:
  # Sur environnement de test: 114 s. linux/13 mars
  # Sur environnement de test: 116 s. linux/13 mars
  # Sur IHM linux avec lex.yy.cpp  linux/13 mars :
  # StripJava  :12.056398   :12.032029   :2   :separer_code_commentaire_chaine
  # StripJava  :17.910808   :5.854410    :3   :SupprimeMacro3
  # Rejeu:
  # StripJava  :12.131741   :12.112692   :2   :separer_code_commentaire_chaine
  # StripJava  :17.335332   :5.203591    :3   :SupprimeMacro3
  if (1) # Cette methode est la plus efficace des 4.
  {

# traces_filter_end

    $b =~ tr/\n//cd ;
    $resultat = $b;

# traces_filter_start

  }

  # Methode 3
  # Sur environnement de test: 115 s. linux/13 mars
  # Sur IHM linux avec lex.yy.cpp  linux/13 mars :
  # StripJava  :12.639091   :12.617534   :2   :separer_code_commentaire_chaine
  # StripJava  :18.928806   :6.289715    :3   :SupprimeMacro3
  # Rejeu:
  # StripJava  :12.395193   :12.376176   :2   :separer_code_commentaire_chaine
  # StripJava  :17.840242   :5.445049    :3   :SupprimeMacro3
  if (0)  # Cette methode est presque la plus efficace des 4.
  {
    my $n=0;
    while ( $b =~ /\n/g )
    {
      #$n++;
      $resultat .= "\n" ;
    }
  }

  # Methode 4
  # Sur environnement de test: 117 s. linux/13 mars
  # Sur IHM linux avec lex.yy.cpp  linux/13 mars :
  # StripJava  :12.641963   :12.624207   :2   :separer_code_commentaire_chaine
  # StripJava  :19.055544   :6.413581    :3   :SupprimeMacro3
  # Rejeu:
  # StripJava  :12.916167   :12.892414   :2   :separer_code_commentaire_chaine
  # StripJava  :18.413305   :5.497138    :3   :SupprimeMacro3
  if (0) # Cette methode n'est pas tres performante
  {
    my $n=0;
    while ( $b =~ /\n/g )
    {
      $n++;
    }
    $resultat = "\n" x $n;
  }

# traces_filter_end

  return $resultat;
}

# traces_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Dumpe la vue Strings.
#-------------------------------------------------------------------------------
sub dumpVueStrings($$)
{
	my ($rt_strings, $stream) = @_;
	#for( my $i =0; $i <= $#{@{$rt_strings}} ; $i++ )
	#{
	#  print $stream "chaine:$i:$rt_strings->[$i]\n";
	#}
	if (! defined $stream) {
		$stream = *STDERR ;
	}

	if (exists $rt_strings->{'strings_values'}) {
		$rt_strings = $rt_strings->{'strings_values'};
	}
	
	for my $id ( keys %$rt_strings ) 
	{
		print $stream "string:$id:".$rt_strings->{$id}."\n";
	}
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Store strip info. These infos could be used later when computing violations
#-------------------------------------------------------------------------------
sub storeStripInfo($$$)
{
  my ($views, $info, $value) = @_;
 
  $views->{'strip_info'}->{$info} = $value;
}

sub createLinesIndex($) {
  my $r_buffer = shift;
  my @index = (undef,0); #Indexes for lines 0 & 1
  # [31/03/21] algo commented because of performance issue in agent scan
  # while ($$r_buffer =~ /\n/g) {
  #   push @index, pos($$r_buffer);
  # }

  # new algo:
  my $pos = 0;
  while ($$r_buffer =~ /(\n|[^\n])/g) {
    $pos++;
    if ($1 eq "\n") {
        push (@index, $pos);
    }
  }
  return \@index;
}

sub createNumLinesComment($) {
	my $r_buffer = shift;
	my $numline = 1;
	my %commentLine;
	while ($$r_buffer =~ /(\n|^\s*\/\*)/mg) {
		if (defined $1 && $1 eq "\n") {
			$numline++;
		}
		else {
			$commentLine{$numline} = 1;
		}
	}
	return \%commentLine;
}

# traces_filter_end

1;
