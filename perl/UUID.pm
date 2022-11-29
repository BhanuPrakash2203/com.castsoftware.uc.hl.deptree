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
package UUID;

use strict;
use warnings;
use Time::HiRes qw( gettimeofday tv_interval );
use Math::BigInt;

my ( $seconds, $microseconds) = gettimeofday;

#srand (time ^ $$ ^ unpack "%L*", ‘ps axww | gzip‘);
#srand ( $seconds * 1000 * 1000 + $microseconds );

my $s = Math::BigInt->new ( $seconds);
$s->bmul ( 1000000 );
$s->badd ( new Math::BigInt ( $microseconds ) );

#print $s->bstr() . "\n";
#print $s->as_hex() . "\n";
my $graine = $s->bmod( 2 ** 32 );
#printf "%x\n", $graine ;

srand ( $graine);


sub new($$)
{
  my ($class, $param) = @_;
  my $self = {};

  bless $self, $class;

#print "Creation d'un UUID a partir de " .$param. "\n" ;

  my @digitArray = ();
  @digitArray [0..29] = 0; # 30 chiffres hexa
  my $digitArrayIndex = 0;

  sub hexrand_len
  {
    my ($len) = @_;
    my $chaine = '';
    for (my $i =0; $i < $len; $i++)
    {
      my $r = int(rand(16));
      $chaine .= sprintf "%x", $r;
      #print "$c\n";
    }
    $chaine;
  }
  sub initRandomArray ($$$)
  {
    my ($digitArray, $digitArrayIndex, $len) = @_;
    for (my $i =0; $i < $len; $i++)
    {
      $digitArray->[$i] = int(rand(16));
    }
  }
  sub alterArrayByNumber($$$)
  {
    my ($digitArray, $digitArrayIndex, $number) = @_;
    while ($number != 0)
    {
      my $mo = $number % 10;
      $number = int ($number / 10 );
      $digitArray->[$$digitArrayIndex++] ^= $mo;
      $$digitArrayIndex = 0  if ( $$digitArrayIndex >= 30);
    }
  }
  sub alterArrayByString($$$)
  {
    my ($digitArray, $digitArrayIndex, $pSt) = @_;
    foreach my $c (  split (//, $pSt ) )
    {
      my $number = ord ($c);
      while ($number > 15 )
      {
        my $mo = $number % 16;
        $number = int ($number / 16 ) ^ $mo;
      }
      $digitArray->[$$digitArrayIndex++] ^= $number;
      $$digitArrayIndex = 0  if ( $$digitArrayIndex >= 30);
    }
  }
  sub readArray($$$)
  {
    my ($digitArray, $digitArrayIndex, $len) = @_;
    my $chaine = '';
    for (my $i =0; $i < $len; $i++)
    {
      my $r = $digitArray->[$$digitArrayIndex++];
      $chaine .= sprintf "%x", $r;
    }
    $chaine;
  }
  initRandomArray(\@digitArray,\$digitArrayIndex,30);
  alterArrayByNumber(\@digitArray,\$digitArrayIndex,$seconds);
  alterArrayByNumber(\@digitArray,\$digitArrayIndex,$microseconds);
  alterArrayByString(\@digitArray,\$digitArrayIndex,$param);
  $digitArrayIndex = 0;
  $self ->{'UUID'} =  join ( '-', ( readArray(\@digitArray,\$digitArrayIndex,8),
                      readArray(\@digitArray,\$digitArrayIndex,4),
                      '4'.readArray(\@digitArray,\$digitArrayIndex,3),
                      '8'.readArray(\@digitArray,\$digitArrayIndex,3),
                      readArray(\@digitArray,\$digitArrayIndex,12)
             )) ;
  return $self;
}

sub e($)
{
  my ($self) = @_;
  print $self ->{'UUID'} ."\n";
  #return ($val1, $val2);
}

sub AsString($)
{
  my ($self) = @_;
  return $self ->{'UUID'};
}
    

if (not defined caller() )
{
  my $demo = new UUID($ARGV[0]);
  $demo->e();
}


1;

