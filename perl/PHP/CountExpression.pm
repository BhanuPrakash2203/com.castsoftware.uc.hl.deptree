package PHP::CountExpression;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::Node;
use PHP::PHPNode;

my $BadIncDecUse__mnemo = Ident::Alias_BadIncDecUse();

my $nb_BadIncDecUse = 0;

# Var pattern should be more complexe to take into account the following :
#       $var[($i+1)*5]
my $VAR_PATTERN = '\$(?:\w|->|\[[^\[\]]*\])+';
my $OP_ARITH = '\s*[\+\-\*\/%]\s*';
my $OP_CONCAT = '\s*\.\s*';
my $INC_DEC = '(?:--|\+\+)';
my $AFFECT = '\s*(?:-=|\+=|\.=|=)\s*';
my $OP_OTHERS = '\s*(?:===|==|!==|!=|<=|=>)\s*';

my $T_UNKNOW = 0;
my $T_ARITH = 3;
my $T_CONCAT = 6;
my $T_VAR = 5;
my $T_ASSIGN = 4;
my $T_PRE_INC = 2;
my $T_POST_INC = 1;

sub CountBadIncDecUse($) {
  my $stmt = shift;

  # add a dummy pattern at beginning to prevent from (index-1) doesn't go out of bound.
  my @T_code=("");
  my @T_kind=(-1);

  my $nb_arith_conflict=0;
  my $nb_concat_conflict=0;
  my $nb_missing_incdec=0;
  my $padding="";

  my $AssignedVar = undef;
  my $AssignOp = undef;

  my $AssignedUsed = 0; # indicates if the assigned var is used in the expression
  my $OtherUsed = 0;    # indicates if other var than the assigned are used in the expression


  while ( $$stmt =~ /\G(${OP_OTHERS})|(${AFFECT})|(${VAR_PATTERN}${INC_DEC})|(${INC_DEC}${VAR_PATTERN})|(${VAR_PATTERN})|(${OP_ARITH})|(${OP_CONCAT})|(.)/sg) {
    if (defined $8) {
      $padding .= $8;
    }
    elsif (defined $1) {
      $padding .= $1;
    }
    else {
      if ($padding ne "") {
		push @T_code, $padding;
        push @T_kind, $T_UNKNOW;
        $padding = "";
      }

      if (defined $5) {
        push @T_code, $5;
        push @T_kind, $T_VAR;    # variable
      }
      if (defined $3) {
        push @T_code, $3;
        push @T_kind, $T_POST_INC;    # post-incdec
      }
      elsif( defined $4) {
        push @T_code, $4;
        push @T_kind, $T_PRE_INC;    # pre-incdec
      }
      elsif( defined $6) {
        push @T_code, $6;
        push @T_kind, $T_ARITH;    # arithm
      }
      elsif( defined $2) {
        push @T_code, $2;
        push @T_kind, $T_ASSIGN;    # assignment
      }
      elsif( defined $7) {
        push @T_code, $7;
        push @T_kind, $T_CONCAT;    # concat
      }
    }
  }
  if ($padding ne "") {
    push @T_code, $padding;
    push @T_kind, 0;    # pre-incdec
    $padding = "";
  }

  # add a dummy pattern to prevent from (index+1) doesn't go out of bound.
  push @T_code, "";
  push @T_kind, -1;    

  for ( my $i=0; $i < scalar (@T_kind); $i++)  {

# FIXME : can an inc/dec var be involved with several conflict rules ? 

    # CASE of an INDE/DEC
    if ( ($T_kind[$i] == $T_POST_INC) || ($T_kind[$i] == $T_PRE_INC)) {

      # Check conflict between inc/dec and ARITH op.
      #  RQ  : difference with CodeSniffer : 
      #     CodeSniffer does not take into account operators that are before
      #     the inc/dec variable ...
      if ($T_kind[$i+1] == $T_ARITH) {
#print STDERR "ARITH CONFLICT : ".$T_code[$i]." conflicts with ".$T_code[$i+1]."\n";
        $nb_arith_conflict ++;
      }
      elsif  ($T_kind[$i-1] == $T_ARITH) {
#print STDERR "ARITH CONFLICT : ".$T_code[$i]." conflicts with ARITH ".$T_code[$i-1]."\n";
        $nb_arith_conflict ++;
      }

      # Check conflict between inc/dec and CONCAT op.
      if ($T_kind[$i+1] == $T_CONCAT) {
#print STDERR "CONCAT CONFLICT : ".$T_code[$i]." conflicts with CONCAT ".$T_code[$i+1]."\n";
        $nb_concat_conflict ++;
      }
      elsif ($T_kind[$i-1] == $T_CONCAT) {
#print STDERR "CONCAT CONFLICT : ".$T_code[$i]." conflicts with CONCAT ".$T_code[$i-1]."\n";
        $nb_concat_conflict ++;
      }
    }

    # CASE of an ASSIGNMENT
    if ($T_kind[$i] == $T_ASSIGN) {
      $AssignOp = $T_code[$i];
      if ($T_kind[$i] != -1) {
        $AssignedVar = $T_code[$i-1];
      }
      else {
        print "EXPRESSION ERROR : assigned var not found in $$stmt\n";
      }
    }

    # CASE of a VARIABLE
    if ($T_kind[$i] == $T_ASSIGN) {
      if (defined $AssignOp) {
        if ( defined $AssignedVar && ($AssignedVar eq $T_code[$i]) ) {
          $AssignedUsed = 1;
        }
        else {
          $OtherUsed = 1;
        }
      }
    }
  }
 
  if (defined $AssignOp) {
    if ($AssignOp =~ /\+=|\-=/) {
      if ($$stmt =~ /=\s*1\s*$/s) {
#print STDERR "MISSING INC/DEC : missing ++/-- in place of $AssignOp\n";
        $nb_missing_incdec++;      
      }
    }
    else {
      my $Var = $AssignedVar;
      # protect all '$', '[]', '()', '+*' presents in the var expression
      # NB : At this time, variables expression can support [, ( and operator.
      #      $var[$i+1] is not recognized ...
      $Var =~ s/([\$\[\]\(\)\*\+\\])/\\$1/sg;
      if ( defined $AssignedVar &&
	   ( ($$stmt =~ /=\s*(?:\(\s*)?${Var}\s*[\+-]\s*1\s*(?:\)\s*)?$/s) ||
	     ($$stmt =~ /=\s*(?:\(\s*)?1\s*\+\s*${Var}\s*(?:\)\s*)?$/s) ) ) {
#print STDERR "MISSING INC/DEC: missing ++/-- for $AssignedVar\n";
        $nb_missing_incdec++;      
      }
    }
  }

  return $nb_arith_conflict + $nb_concat_conflict + $nb_missing_incdec; 
}

sub CountExpression($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_BadIncDecUse = 0;


  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $BadIncDecUse__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Unks = GetNodesByKind( $root, UnknowKind);

  for my $unk (@Unks) {
    my $stmt = GetStatement($unk);
#print "----------------\n";
    my $nb = CountBadIncDecUse($stmt);
#print "$$stmt ==> ".($nb)." violations\n";
    $nb_BadIncDecUse += $nb;
  }

  $ret |= Couples::counter_add($compteurs, $BadIncDecUse__mnemo, $nb_BadIncDecUse );

  return $ret;
}


1;
