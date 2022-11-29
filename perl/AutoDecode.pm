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
# DESCRIPTION: Composant de chargement d'un fichier source
#----------------------------------------------------------------------#


package AutoDecode;

# les modules importes
use strict;
use warnings;
use Encode;
use Encode 'from_to';
use Encode 'decode';

use Erreurs; # pour les traces
use Timeout;

# prototypes prives
sub BytesFrequencies ($);
sub DetectEncodingWithBytesFrequencies ($);
sub DetectEncodingWithBom ($);
sub detect_binary_file($$);
sub DecodeWithEncodingList ($$);
sub autodetect_encoding ($$);
sub BinaryBufferToTextBuffer ($$;$$);


#-------------------------------------------------------------------------------
# DESCRIPTION: Contournement pour Active perl 5.8.7
#-------------------------------------------------------------------------------
my $use_utf8 = 1;
# 0 pour test
if ($^O and $^O eq 'MSWin32' ) # par opposition a 'cygwin'
{
  if ($^V and $^V lt v5.10.0)
  {
    printf STDERR "Perl version is v%vd sur %s \n", $^V,  $^O ;  # version de Perl
    print STDERR   "Active perl 5.8.7 supporte mal les expressions rationnelles utf-8.\n";
    print STDERR   "Support unicode desactive\n";
    $use_utf8=0;
  }
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Mesure la frequences des octets
# sur un buffer binaire.
#-------------------------------------------------------------------------------
sub BytesFrequencies ($)
{
  my ( $buffer ) = @_;
  my @bytes =();
  $#bytes = 256 ;
  for (my $i=0; $i< 256;$i++)
  {
    $bytes[$i] =0;
  }
  my $len = length($$buffer) ;
  my $c;
  for (my $i=0; $i< $len;$i++)
  {
    $c=  vec ( $$buffer, $i, 8);
    $bytes[$c] ++ ;
  }
  return \@bytes;
}


# Mesure la frequences des sequence de deux octets
# sur un buffer binaire.
sub DoubleBytesFrequencies ($)
{
  my ( $buffer ) = @_;
  my @bytes_by_2 =();
  $#bytes_by_2 = 256 * 256;
  for (my $i=0; $i< 256 * 256;$i++)
  {
    $bytes_by_2[$i] =0;
  }
  my $len = length($$buffer) ;
  my $byte_value;
  my $prev ;
  
  my $index = 0;
  $prev = vec ( $$buffer, $index, 8);
  for (my $index=1; $index< $len; $index++)
  {
    $byte_value = vec ( $$buffer, $index, 8);
    $bytes_by_2[$prev*256 + $byte_value] ++ ;
    $prev = $byte_value ;
  }
  return \@bytes_by_2;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Detecte l'encodage en se basant sur la frequence des octets.
# Cette fonction ne fonctionne que pour les encodages suivants:
# 'cp850' ; 'windows-1252' ; 'iso-8859-15' ; 'iso-8859-1' ; 'us_ascii' ;
#-------------------------------------------------------------------------------
sub DetectEncodingWithBytesFrequencies ($)
{
  my ( $bytes ) = @_;
  my $encoding ;
  my $score_8859_1 = $bytes->[0xe0] + $bytes->[0xe9] + $bytes->[0xe8]; # e acute et a grave et e grave
  my $score_cp850  = $bytes->[0x85] + $bytes->[0x82]; # e acute et a grave

  if ( $score_cp850 + $score_8859_1 > 0)
  {
    if  ( $score_cp850 > $score_8859_1 )
    {
      $encoding = 'cp850' ;
    }
    else
    {
      my $score_windows1252 = $bytes->[0x80]; # euro sign
      my $score_8859_15 = $bytes->[0xa4]; # euro sign
      if ( $score_windows1252 + $score_8859_15 > 0 )
      {
        if ( $score_windows1252 > $score_8859_15)
        {
          $encoding = 'windows-1252' ;
        }
        else
        {
          $encoding = 'iso-8859-15' ;
        }
      }
      else
      {
        $encoding = 'iso-8859-1' ;
      }
    }
  }

  if (not defined $encoding)
  {
    my $s = 0;
    for (my $i=128; $i<256; $i++)
    {
      $s += $bytes->[$i];
    }
    if ( $s > 0)
    {
      $encoding = 'inconnu' ; # encodage non reconnu.
    }
    else
    {
      $encoding = 'us_ascii' ;
    }
  }
  return $encoding;
}

# Detecte l'encodage en se basant sur la frequence de 
# deux octets successifs
# Cette fonction n'ets prevue que pour les encodages euc.
sub DetectEncodingWithDoubleBytesFrequencies ($)
{
  my ( $doubleBytesArray ) = @_;
  my $encoding ;

  my $score_euc = 0;
  my $score_non_euc = 0;
  for (my $i=0xa1; $i<=0xfe; $i++) # code euc double octet
  {
    for (my $j=0xa1; $j<=0xfe; $j++) # code euc double octet
    {
      $score_euc += $doubleBytesArray->[$i * 256 + $j];
    }
    for (my $j=0x80; $j<=0xa0; $j++) 
    #  code non euc double octet # a l'exception d'ascii 
    {
      $score_non_euc += $doubleBytesArray->[$i * 256 + $j];
      $score_non_euc += $doubleBytesArray->[$j * 256 + $i];
    }
    my $j = 0xff;
      $score_non_euc += $doubleBytesArray->[$i * 256 + $j];
      $score_non_euc += $doubleBytesArray->[$j * 256 + $i];
  }
 
  #print STDERR 'scores :  euc ' . $score_euc . ' non euc: ' .  $score_non_euc . ' -> ' .  ( 1+ $score_euc) /  ( 2 + $score_euc + $score_non_euc ) . ' ';
  print STDERR Erreurs::GetCurrentFilenameTrace() . "\n" ;

  return $encoding;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Renvoi une chaine identifiant l'encodage du fichier,
# en se basant sur la sequence de quelques octets donnant cette information
# contenue dans le debut de fichier et connue sous
# le nom de BOM (byte order marker)
#
# UTF-8     EF BB BF *
# UTF-16 Big Endian     FE FF
# UTF-16 Little Endian     FF FE
# UTF-32 Big Endian     00 00 FE FF
# UTF-32 Little Endian     FF FE 00 00
# SCSU     0E FE FF
# UTF-7     2B 2F 76
#     puis l'un des octets suivants: [ 38 | 39 | 2B | 2F ]
# UTF-EBCDIC     DD 73 66 73
# BOCU-1     FB EE 28
#-------------------------------------------------------------------------------
sub DetectEncodingWithBom ($)
{
  my ( $bytes_buffer ) = @_;
  my $encoding;

use bytes ;
  # Detection du BOM Unicode si present.
  if ( $$bytes_buffer =~ /\A\x{ef}\x{bb}\x{bf}/ )
  {
    $encoding = 'utf8' ;
  }
  elsif ( $$bytes_buffer =~ /\A\x{fe}\x{ff}/ )
  {
    $encoding = 'utf16be' ;
  }
  elsif ( $$bytes_buffer =~ /\A\x{ff}\x{fe}/ )
  {
    $encoding = 'utf16le' ;
  }
  elsif ( $$bytes_buffer =~ /\A\x{dd}\x{73}\x{66}\x{73}/ )
  {
    $encoding = 'utf-edcdic' ;
    # FIXME: Comment tester?
  }
no bytes ;

  return $encoding;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Detecte les fichiers binaires,
#                                                                               #bt_filter_line
# NB: certains fichiers cobol contiennent des sequences binaires.               #bt_filter_line
#-------------------------------------------------------------------------------
sub detect_binary_file($$)
{
  my ($bytes_stat, $buffer) = @_;

  # caracteres de controle (connue sous le nom
  # de C0)  Sauf: 0x09 (tab) 0x0a (lf) 0x0d (cr)
  my $score_binary  = 0;
  for ( my $i =0 ; $i< 32; $i++ )
  {
    next if (  ($i ==9 ) or ( $i==10 ) or ($i ==13) );
    $score_binary  += $bytes_stat->[$i] ;
  }

  # NB: evite la division par zero
  # optimise le traitement, notamment pour un vrai fichier ascii.
  return  0 if ( $score_binary == 0);

  my $ratio_binaire =  $score_binary / length($$buffer) ;
  #print STDERR "Ratio octets binaires: $ratio_binaire \n";                     # traces_filter_line
  #return $score_binary / length($$buffer);                                      # traces_filter_line
  # Un fichier binaire pur serait a 0.125
  # un peu moins avec quelques chaines
  # un fichier ascii ou utf-8 pur serait a 0.
  # un fichier UTF-16 peut-etre a 0.5
  if ( $ratio_binaire > 0.04 )
  {
    my $re_control = '(?:[\x{0}-\x{08}\x{0b}\x{0c}\x{0e}-\x{1f}])';
    # Recherche de deux octets binaires successifs.
    if  ( $$buffer =~ m/$re_control$re_control/smgo )
    {
      # Il ne s'agit vraisemblablement pas d'un fichier utf-16.
      return 1;
    }
  }
  return 0;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Cette fonction decode la vue binaire,
# en utilisant le premier encodage qui marche
# dans la liste du parametre encoding_order
#-------------------------------------------------------------------------------
sub DecodeWithEncodingList ($$)
{
  my ( $octets, $encoding_order ) = @_;
  my $c;
  my $ok = 0;
  my $detected_encoding ;
  my $sig_die = $SIG{__DIE__}  ;
  # FIXME: ne permet pas de savoir sur quelle ligne...
                                                                                # traces_filter_line
  # On empeche le detournement du signal die                                    # traces_filter_line
  # $SIG{__DIE__} = sub { die $_; } ;                                           # traces_filter_line
                                                                                # traces_filter_line
  $SIG{__DIE__} = 'DEFAULT' ;
  for my $encoding ( @{$encoding_order} )
  {
    if ( $ok == 0)
    {
      $ok = 1 ;
      eval
      {
        # FIXME: D'apres les pages man de perl:
        # FIXME:   CAVEAT: The following operations look the same but
        # FIXME:   are not quite so;
        # FIXME:   from_to($data, "iso-8859-1", "utf8"); #1
        # FIXME:   $data = decode("iso-8859-1", $data);  #2
        # FIXME: La fonction 'decode' provoque un bug dans les expressions rationnelles
        # FIXME:   sous active perl. from_to non.
        # FIXME: Cela semble signifier que Active perl 5.8.7 ne supporte
        # FIXME:   pas les expressions rationnelles utf-8.
        # FIXME: Toutefois, pour le debug, l'utilisation de from_to empeche
        # FIXME:   l'enregistrement des vues dans des fichiers
        # FIXME:   avec l'encodage d'origine.
        if ($use_utf8 > 0.5 )
        {
          # pour Active Perl 5.10
          # et les perls (5.8 et 5.10) des autres
          # environnements (cygwin, linux, strawberry)
          # Dans ce cas, les buffers contienent des caracteres unicode.
          $c = decode($encoding, $$octets, Encode::DIE_ON_ERR);
        }
        else
        {
          # contournement pour ActivePerl5.8
          # Dans ce cas, les buffers contienent les octets utf-8 des caracteres.
          $c = $$octets;
          from_to( $c, $encoding, 'utf8', Encode::DIE_ON_ERR);
        }
      };
      if ($@)
      {
        Timeout::DontCatchTimeout();   # propagate timeout errors
        $ok=0;
      }
      $detected_encoding = $encoding;
    }
  }
  $SIG{__DIE__} = $sig_die ; # Puis on le restitue.
  my @rep =  ($ok, $c, $detected_encoding);
  return \@rep;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Autodetection de l'encodage
# en se basant sur le BOM
# sinon sur des encodage multi-octets biens connus
# ou definis par l'appelant
# sinon sur un encodage mono-octets
#-------------------------------------------------------------------------------
sub autodetect_encoding ($$)
{
  my ( $bytes_buffer, $defaultEncoding ) = @_;
  my $status ;
  # Liste de la forme: ( "utf8", "iso-8859-1", "iso-8859-15", "windows-1252" )
  my @encoding_order;
  my $b = BytesFrequencies($bytes_buffer);
  my $doubleByteFreqArray = DoubleBytesFrequencies($bytes_buffer);


  my  $encodage ;
  # Recherche une marque d'encodage, en debut de fichier.
  $encodage = DetectEncodingWithBom($bytes_buffer);
  if (defined $encodage )
  {
    # Tentative avec l'indication de debut de fichier qui est relativement fiable
    @encoding_order = ( $encodage );
  }
  else
  {
    # Tentative avec le peu d'indication disponible; moins deterministe


    # Si le fichier est binaire, il n'a pas d'encodage.
    my $is_bin = detect_binary_file($b, $bytes_buffer);
    if ( $is_bin > 0.5 )
    {
      return undef ;
    }



    # Les encodages multioctets bien connus,
    # pouvant etre autodetectes
    # Fonctionne comme Encode::Guess
    # http://perldoc.perl.org/Encode/Guess.html
    if ( (defined $defaultEncoding) and ($defaultEncoding ne '') )
    {
      # Utilisation des encodages propose par l'utilisateur.
      @encoding_order = split ( ',' , $defaultEncoding );
    }
    else
    {
      @encoding_order = ( 'us-ascii',
                          'utf8',
                           # shiftjis peut accepeter des fichiers iso-8859-1
                           # qui pour seuls caracteres non-ascii ont des  00e9
                           # pour cette raison, on le desctive par defaut.
                           #"shiftjis",  # utile pour le japonais
                          'euc-jp',
                           #"shiftjis"
                           #, "7bit-jis"
      );
    }
  }
  $status = DecodeWithEncodingList ( $bytes_buffer, \@encoding_order );
  if ( $status->[0] == 0 ) # mode  de secours: l'encodage n'a pas ete reconnu, on en prend un au hasard
  {

    # For mono bytes encodings:
    $encodage = DetectEncodingWithBytesFrequencies($b);

    # For multi bytes encodings:
    # FIXME
    my $encodage_multybyte = DetectEncodingWithDoubleBytesFrequencies($doubleByteFreqArray);


    # mode mono-octets: l'encodage n'a pas ete reconnu, on prend un encodage mono-octet
    # dont on est sur qu'il fonctionera.
    @encoding_order = ( $encodage, 'cp850', 'windows-1252' );
    $status = DecodeWithEncodingList ( $bytes_buffer, \@encoding_order );
  }

  return $status;
}


# Suppression des retours a la ligne dans les noms de fichier
# pour clarifier les traces de debug                                                           # traces_filter_line
#sub RemoveNonPrintableCharacters($)
#{
  #my ($buffer) = @_;
#
  #$buffer =~ s#[\x{000A}\x{000B}\x{000C}\x{000D}\x{0085}\x{2028}\x{2029}]|\x{000D}\x{000A}##g;
  #return $buffer;
#}
sub RemoveNonPrintableCharacters($)
{
  my ($buffer) = @_;

  my $x2028 = pack("U0C*", 0xe2, 0x80, 0xa8); # U+2028 LINE SEPARATOR
  my $x2029 = pack("U0C*", 0xe2, 0x80, 0xa9); # U+2029 PARAGRAPH SEPARATOR
  my $x0085 = pack("U0C*", 0xc2, 0x85);       # U+0085 <control>
  my $x000a = pack("U0C*", 0x0a);             # U+000A <control>
  my $x000b = pack("U0C*", 0x0b);             # U+000B <control>
  my $x000c = pack("U0C*", 0x0c);             # U+000C <control>
  my $x000d = pack("U0C*", 0x0d);             # U+000D <control>
  $buffer =~ s#(?:$x000a|$x000b|$x000c|$x000d|$x0085|$x2028|$x2029)|$x000d$x000a##g;
  return $buffer;
}

    # Uniformisation des fins de lignes
    # See : http://unicode.org/reports/tr13/tr13-9.html
    # See : http://www.unicode.org/unicode/reports/tr18/#Line_Boundaries

    #  According to VBLS80.doc
    #                         The Microsoft Visual Basic Language Specification
    #                         Version 8.0
    #                         Paul Vick
    #                         Microsoft Corporation
    #    Line Terminators
    #    Unicode line break characters separate logical lines.
    #    LineTerminator  ::=
    #         < Unicode carriage return character (0x000D) >  |
    #         < Unicode linefeed character (0x000A) >  |
    #         < Unicode carriage return character >  < Unicode linefeed character >  |
    #         < Unicode line separator character (0x2028) >  |
    #         < Unicode paragraph separator character (0x2029) >
sub UnicodeUniformiseEndLine($)
{
  my ($buffer) = @_;

  my $x2028 = pack("U0C*", 0xe2, 0x80, 0xa8); # U+2028 LINE SEPARATOR
  my $x2029 = pack("U0C*", 0xe2, 0x80, 0xa9); # U+2029 PARAGRAPH SEPARATOR
  my $x0085 = pack("U0C*", 0xc2, 0x85);       # U+0085 <control>
  my $x000a = pack("U0C*", 0x0a);             # U+000A <control>
  my $x000b = pack("U0C*", 0x0b);             # U+000B <control>
  my $x000c = pack("U0C*", 0x0c);             # U+000C <control>
  my $x000d = pack("U0C*", 0x0d);             # U+000D <control>
  $buffer =~ s#$x000d$x000a|(?:$x000a|$x000b|$x000c|$x000d|$x0085|$x2028|$x2029)#\n#g;
    #$c =~ s#\x{000D}\x{000A}|[\x{000A}\x{000B}\x{000C}\x{000D}\x{0085}\x{2028}\x{2029}]#\n#g;
  return $buffer;
}

sub removeEOLNullBytes($) {
  my $buf = shift;

  my $x2028 = pack("U0C*", 0xe2, 0x80, 0xa8); # U+2028 LINE SEPARATOR
  my $x2029 = pack("U0C*", 0xe2, 0x80, 0xa9); # U+2029 PARAGRAPH SEPARATOR
  my $x0085 = pack("U0C*", 0xc2, 0x85);       # U+0085 <control>
  my $x000a = pack("U0C*", 0x0a);             # U+000A <control>
  my $x000b = pack("U0C*", 0x0b);             # U+000B <control>
  my $x000c = pack("U0C*", 0x0c);             # U+000C <control>
  my $x000d = pack("U0C*", 0x0d);             # U+000D <control>
  my $x0000 = pack("U0C*", 0x00);             # U+0000
  #$$buf =~ s#(\x{00}\x{00})+##g
  $$buf =~ s#(?:$x0000$x0000)+($x000a|$x000b|$x000c|$x000d|$x0085|$x2028|$x2029)#$1#g
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Transformation d'une vue binaire en une vue textuelle
# Decodage des caracteres a partir de la vue binaire
# Suppression des \r parasites, lorsque necessaire.
#-------------------------------------------------------------------------------
sub BinaryBufferToTextBuffer ($$;$$)
{
  my ($fileName, $octets, $defaultEncoding, $detectedEncoding)=@_;
  # Suppression des retours a la ligne dans les noms de fichier
  # pour clarifier les traces de debug                                                           # traces_filter_line
  $fileName = RemoveNonPrintableCharacters( $fileName );

  # We found that some cobol file can have a peer number of null bytes before
  # the end of line sequence character.
  removeEOLNullBytes($octets);


  my $status =  autodetect_encoding( $octets, $defaultEncoding );

  if ( not defined $status)
  {
    # Fichier binaire.
    return undef ;
  }

  my ($ok, $c, $detected_encoding) =  @{$status} ;

  if ($ok == 1)
  {
    $$detectedEncoding = $detected_encoding if ( defined $detectedEncoding);
  }
  else
  {
    print STDERR "Fichier ".  $fileName . " echec d'ouverture\n" ;
    return undef ;
  }

  # Uniformisation du codage des fins de lignes.
  if ( $detected_encoding =~  '^utf(?:8|16)')
  {
    $c = UnicodeUniformiseEndLine($c);
  }
  else
  {
    # Dans la cas CP850, il ne faut pas remplacer 0x85 qui correspond a:  A GRAVE
    # En theorie, le x000D marque une nouvelle ligne,                           #bt_filter_line
    # mais il existe du code cobol ou ce n'est pas le cas.                      #bt_filter_line
    $c =~ s#\x0D\x0A|[\x0A]#\n#g;
  }

  my $xfffe = pack("U0C*", 0xeb, 0xbf, 0xbe); # U+FFFE  - No such unicode character name in database 
  my $xfeff = pack("U0C*", 0xe2, 0x80, 0xa8); # U+FEFF ZERO WIDTH NO-BREAK SPACE
  # Suppression du BOM Unicode si present.
  $c =~ s#^[\x{fffe}\x{feff}]##;
  #$c =~ s#^(?:$xfffe|$xfeff)##;

  return $c;
}


1;
