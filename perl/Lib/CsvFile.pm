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

# Composant: Framework
#----------------------------------------------------------------------#
# DESCRIPTION: Composant de gestion d'objets fichiers CSV contenant des
# resultats d'outils d'alarmes.
#----------------------------------------------------------------------#

package CsvFile;

# les modules importes
use strict;
use warnings;
use Traces;
use Couples;
use IsoscopeDataFile;

# prototypes publics
sub new($$);
sub dump($$;);
sub rewindCouples($); # bt_filter_line
sub nextCouples($$;); # bt_filter_line

# prototypes prives
sub createCouples($$$);
sub getName($);

my $debug = 0; # traces_filter_line

my $csv_sep = ";";   # separateur de champs

my $COMPTEUR_EMPTY_VALUE = '';
my $RETOUR_FLAG_ERREUR = 1;


sub SetEmptyAndFlag($$)
{
  my ($empty, $flag) = @_;
  $COMPTEUR_EMPTY_VALUE = $empty;
  $RETOUR_FLAG_ERREUR = $flag;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Cree des couples a partir d'identificateurs et de leurs valeurs associées
#-------------------------------------------------------------------------------
sub createCouples($$$)
{
    my ($rIdentifiers, $rValues, $rstatus) = @_;

    my $status = $$rstatus;

    my $couples = new Couples();

    my @tb_identifiers = @{$rIdentifiers};
    my @tb_values = @{$rValues};

    for my $identifierIndex (0..$#tb_identifiers)
    {
        if (defined $tb_values[$identifierIndex])
        {
            $status |= Couples::counter_add($couples, $tb_identifiers[$identifierIndex], $tb_values[$identifierIndex]);
        }
        else
        {
            $status |= Couples::counter_add($couples, $tb_identifiers[$identifierIndex], $COMPTEUR_EMPTY_VALUE);
            print STDERR "Valeur indefinie du comptage " . $tb_identifiers[$identifierIndex] . " pour le fichier " . $tb_values[0] . "\n" if ($debug); # traces_filter_line
        }
    }

    $$rstatus = $status;

    return $couples;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub new($$)
{
    my ($class, $name) = @_;

    my $self = {};

    $self->{Name} = $name;

    $self->{hMneMoLists} = {};
    $self->{hMnemoLists}->{'Binary'} = IsoscopeDataFile::getBinaryMnemos();
    $self->{hMnemoLists}->{'Unknown'} = IsoscopeDataFile::getUnknownMnemos();

    $self->{hSections} = {}; # types non triviaux (acces direct)
    $self->{tbSections} = ['Binary', 'Unknown']; # tous types

    $self->{hTbCouples} = {};
    $self->{hTbCouples}->{'Binary'} = [];
    $self->{hTbCouples}->{'Unknown'} = [];

    $self->{hNbCouples} = {};
    $self->{hNbCouples}->{'Binary'} = 0;
    $self->{hNbCouples}->{'Unknown'} = 0;

    $self->{SectionPos} = 0; # numero de la section en cours de scrutation ligne par ligne
    $self->{CouplePos} = -1; # numero de la derniere ligne de section couramment scrutee

    my $fh;

    if (! open $fh, "<$name")
    {
        print STDERR "Unable to read $name: $!\n";
        return undef;
    }

    my $section = undef;
    my $type = undef;

    my $waitingSection = 1;

    my $status = 0;

    my $ligne = 0;

    my %headerHash = ();
    $self->{header_hash} = \%headerHash;
    local $/ = "\n";

    while (<$fh>)
    {
        my $compteurs = undef;

        $ligne++;

        print STDERR "Ligne $ligne : /" . $_ . "/\n" if ($debug != 0);        # traces_filter_line

        $_ =~ s/\s*\z//;

        if (/\A#\s*(.*)/)                                                            # bt_filter_line
        {                                                                     # bt_filter_line
          my $headerLine = $1;
          # Lignes d'entete de fichier de comptage
          my @tb_values = split('\s*'.$csv_sep.'\s*', $headerLine);
          my $key = $tb_values[0] || '';                                      # bt_filter_line
          my $value = $tb_values[1] || '';                                    # bt_filter_line
          print STDERR "CsvFile constructor: $key => $value \n" if ($debug);  # bt_filter_line # traces_filter_line
          if ( $value !~ /\A\s*\z/ )
          {
            $self->{header_hash}->{$key} = $value;
          }
        }                                                                     # bt_filter_line
        else                                                                  # bt_filter_line
        {
            if (! /$csv_sep/)
            {
                if (! /\w/)
                {
                    print STDERR "Presence d'une ligne vide dans $self->{Name}\n";
                }
                else
                {
                    # ligne contenant le nom d'un type de fichier
                    # $section = $_;
                    # print STDERR "SECTION : /" .$section . "/\n" if ($debug != 0); # traces_filter_line
                    # $waitingSection = 0;
                    my $line = $_;
                    if ($line =~ /^section=(\w+)/)
                    {
                        my $section_name = $1;
                        $section = $section_name;
                    }
                    $waitingSection = 0;
                }
            }
            elsif (/\ADat_FileName/)
            {
                # ligne d'en-tete d'un type de fichier
                if (! defined($section))
                {
                    # la ligne d'en-tete n'est pas precedee d'un ligne definissant
                    # le type de fichier
                    # il s'agit d'un cas de compabilite avec une version de format
                    # de sortie mono-langage
                    $section = 'waiting';
                    delete $self->{hMnemoLists}->{$section} if (defined($self->{hMnemoLists}->{$section}));
                    $waitingSection = 1;
                }

                if (! defined($self->{hMnemoLists}->{$section}))
                {
                    # memorisation de la liste des noms de mnemoniques
                    # d'un nouveau type de fichier
                    my @tbFields = split($csv_sep);
                    $self->{hMnemoLists}->{$section} = \@tbFields;
                    if ($waitingSection == 0)
                    {
                        $self->{hTbCouples}->{$section} = [];
                        $self->{hNbCouples}->{$section} = 0;
                        $self->{hSections}->{$section} = 1;
                        push(@{$self->{tbSections}}, $section);
                        print STDERR "Memorisation des mnemoniques du type : /" .$section . "/\n" if ($debug != 0); # traces_filter_line
                        $section = undef;
                    }
                }
            }
            else
            {
                # ligne de valeurs
                # FIXME: on a interet a ce que les mnemoniques du type aient ete prealablement definis ...

                # extraction des valeurs et determination du type du fichier
                my @tb_values = split($csv_sep);
                # type is the content of the counter Dat_Language
                $type = $tb_values[1];
                $type = 'Unknown' if ($type eq "");

                if ($waitingSection == 1)
                {
                    if ($type ne 'Unknown' && $type ne 'Binary')
                    {
                        if (!defined $self->{hMnemoLists}->{$type})
                        {
                            # reaffectation de mnemoniques en attente de type
                            # au type lu dans les valeurs de la ligne courante
                            $self->{hMnemoLists}->{$type} = $self->{hMnemoLists}->{'waiting'};
                            $self->{hSections}->{$section} = 1;
                            $self->{hTbCouples}->{$section} = [];
                            $self->{hNbCouples}->{$section} = 0;
                            push(@{$self->{tbSections}}, $type);
                            print STDERR "Basculement de mnemoniques de waiting vers le type : /" .$type . "/\n" if ($debug != 0); # traces_filter_line
                        }
                        $waitingSection = 0; # la 1ere ligne suivant une declaration de mnemoniques
                                             # et contenant des comptages d'un source de type connu
                                             # ne doit pas presenter un type deja connu
                                             # on est en principe dans le cas d'un fichier CSV mono-langage ...
                        delete $self->{hMnemoLists}->{'waiting'};
                        $section = undef;
                    }
                }

                if (defined $self->{hMnemoLists}->{$type})
                {
                    $compteurs = createCouples($self->{hMnemoLists}->{$type}, \@tb_values, \$status);
                    push(@{$self->{hTbCouples}->{$type}}, $compteurs);
                    $self->{hNbCouples}->{$type}++;
                }
                else
                {
                    $status |= $RETOUR_FLAG_ERREUR;
                    Traces::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'configuration mnemoniques', ''); # traces_filter_line
                    print STDERR "Liste de mnemoniques non definis pour le type de fichier $type cf. $tb_values[0]\n";
                }
            }
        }

        if ($status != 0)
        {
            print STDERR "Erreur de lecture de " . $self->{Name} . " ligne $ligne\n";
            last;
        }
    }

    close $fh;

    my $returnedValue = undef;

    if ($status == 0)
    {
        bless $self, $class;
        $returnedValue = $self;
    }

    return $returnedValue;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: retourne le nom
#-------------------------------------------------------------------------------
sub getName($)
{
    my ($self) = @_;

    return $self->{Name};
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Listage ordonne du contenu d'un fichier CSV section par types de fichiers analyses
#-------------------------------------------------------------------------------
sub dump($$;)
{
    my ($self, $outFile) = @_;

    my $fOut;

    if (! defined $outFile)
    {
        $fOut = \*STDOUT;
    }
    else
    {
        if (! open($fOut, ">$outFile"))
        {
            print STDERR "Impossible de creer le fichier $outFile\n";
            Traces::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'Creation fichier', ''); # traces_filter_line
            return $RETOUR_FLAG_ERREUR;
        }
    }

# bt_filter_start

    my $nbHeaderFields = scalar ( keys ( %{  $self->{header_hash} } ) );
    if ( $nbHeaderFields > 0 ) # toujours vrai 
      # vu que le contexte Bouygues n'est plus gere dans cette branche.
    {
        my %metadata_to_csv_field_name= (
        # attribut de l'objet => token du fichier csv
            version_count => 'version_count',
            #username => 'user',
            app_version => 'app_version',
            app_type => 'app_type'
        );

        print $fOut "#Info \n" ;
        # Enregistrement des informations obligatoires.
        for my $key (keys %metadata_to_csv_field_name)
        {
            my $field_name = $metadata_to_csv_field_name{$key};
            my $value = $self->{header_hash}->{$key} || '';
            print $fOut '# ' . $field_name . $csv_sep . $value . "\n" ;
        }
        # Enregistrement des autres informations.
        for my $key (keys %{ $self->{header_hash} } )
        {
            if (not defined $metadata_to_csv_field_name{$key})
            {
              my $value = $self->{header_hash}->{$key} || '';
              print $fOut '# ' . $key . $csv_sep . $value . "\n" ;
            }
        }
    }

# bt_filter_end
    #------------------------------------------------------------------------
    # Group section by unified techno :
    # -----------------------------------------------------------------------

    my %H_SubTechno = ('Cpp' => 'CCpp', 'C' => 'CCpp', 'Hpp' => 'CCpp',
                       'ObjCpp' => 'ObjCCpp', 'ObjC' => 'ObjCCpp', 'ObjHpp' => 'ObjCCpp' );
    my %H_Unified = ();
    my @T_Independent = ();
    for my $section (@{$self->{tbSections}}) {

      # Check if the section corresponds to a subtechno.
      if (exists $H_SubTechno{$section}) {
        my $unified = $H_SubTechno{$section};
	if ( ! exists $H_Unified{$unified} ) {
	  my @newUnified = ();
	  $H_Unified{$unified} = \@newUnified;
	}
	push @{$H_Unified{$unified}}, $section;
      }
      else {
        push @T_Independent, $section;
      }
    }

    # Dump unified technos
    for my $unifiedTechno (keys %H_Unified)
    {
      #print $fOut "unified=$unifiedTechno\n";
      for my $section1 (@{$H_Unified{$unifiedTechno}}) {
        dumpSection($self, $fOut, $section1);
      }
      #print $fOut "end-unified\n";
    }

    # Dump independent technos.
    for my $section2 (@T_Independent)
    {
      dumpSection($self, $fOut, $section2);
    }

    if ($fOut != \*STDOUT)
    {
        close($fOut);
    }

    return 0;
}

sub dumpSection($$) {
	my $self = shift;
        my $fOut = shift;
	my $section = shift;

        if (($section eq 'Binary') || ($section eq 'Unknown'))
        {
            return; # pour BT
        }
        print STDERR "CsvFile::dump section $section\n" if ($debug != 0); # traces_filter_line
        print $fOut "section=$section\n";                                 # bt_filter_line
        for my $mnemo (@{$self->{hMnemoLists}->{$section}})
        {
            print $fOut $mnemo . $csv_sep ;
        }
        print $fOut "\n";

        for my $compteurs (@{$self->{hTbCouples}->{$section}})
        {
            print STDERR "Compteurs du fichier " . $compteurs->{'Dat_FileName'} . "\n" if ($debug != 0); # traces_filter_line
            for my $mnemo (@{$self->{hMnemoLists}->{$section}})
            {
                print $fOut $compteurs->{$mnemo};
                print $fOut $csv_sep;
            }
            print $fOut "\n";
        }
}
# bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Repositionnement en debut de lecture sequentielle de resultats
#-------------------------------------------------------------------------------
sub rewindCouples($)
{
    my ($self) = @_;

    $self->{SectionPos} = 0;
    $self->{CouplePos} = -1;

    return 0;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Extraction d'une structure de donnees de comptages lors du balayage d'un objet CsvFile
#-------------------------------------------------------------------------------
sub nextCouples($$;)
{
    my ($self, $fOut) = @_;

    my $section = undef;

    $fOut = \*STDERR if (! defined $fOut and $debug != 0); # traces_filter_line

    my $found = 0;

    while ($found == 0)
    {
        if ($self->{SectionPos} > $#{$self->{tbSections}})
        {
            # on a lu tous les couples (mnemo-valeur)
            # de tous les fichiers de codes sources analyses
            return undef;
        }
        $section = $self->{tbSections}->[$self->{SectionPos}];
        print STDERR "nextCouples => Section : $section\n" if ($debug != 0); # traces_filter_line

        $self->{CouplePos}++;
        if (($self->{CouplePos} + 1) > $self->{hNbCouples}->{$section})
        {
            # on s'apprete a parcourir les valeurs obtenues pour
            # un autre type de fichier de code source
            $self->{SectionPos}++;
            $self->{CouplePos} = -1;
        }
        else
        {
            # pret pour lire les couples (mnemo-valeur) d'un ficher de code source
            $found = 1;
        }
    }

    my $compteurs = $self->{hTbCouples}->{$section}->[$self->{CouplePos}];

    {
        print STDERR "Valeurs du fichier " . $compteurs->{'Dat_FileName'} . "\n" if ($debug != 0); # traces_filter_line

        if (defined $fOut)
        {
            for my $mnemo (@{$self->{hMnemoLists}->{$section}})
            {
                print $fOut $compteurs->{$mnemo};
                print $fOut $csv_sep;
            }

            print $fOut "\n";
        }
    }

# FIXME:    if ($fOut != \*STDOUT && $fOut != \*STDERR)
# FIXME:    {
# FIXME: #        close($fOut);
# FIXME:    }

    return $compteurs;
}

sub getHeader($)
{
    my ($self) = @_;
    return $self->{header_hash};
}

# bt_filter_end

1;
