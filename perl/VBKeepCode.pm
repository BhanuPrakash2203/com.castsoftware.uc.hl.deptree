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
# Description: Composant de separation des chaines commentaires et codes, pour VB.net

package VBKeepCode;
use strict;
use warnings;

use SourceLoader ;

use StripUtils;
use StripUtils qw(
        garde_newlines
          warningTrace
          configureLocalTraces
          StringStore
         );
#StripUtils::init('StripVbDotNet', 0);
#StripUtils::init('VBKeepCode', 0);

# TODO Supprimer les annotations


sub addDateId($$$)
{
    my ($r_date, $content, $id) =@_;
    $r_date->{$id}=  $content;
    return undef;
}


# ebauche pour alertes
sub addCommentNode($$$$)
{
    my ($r, $comment, $type, $unused2) =@_;
    $r->{'comment'} .= $type . $comment ;
    $r->{'MixBloc'} .= '/* C */';
    return undef;
}


# ebauche pour alertes
sub addCodeLine($$$$)
{
    my ($r, $content, $indent, $unused2) =@_;
    $r->{'code'} .= $indent . $content ;
    $r->{'MixBloc'} .= $indent.$content ;
    return undef;
}

# Lecture de la chaine jusqu'a la fin de chaine.
sub VbCloseString($$$)
{

    my ($unused, $stringid, $texte ) = @_; 
    my ($line) = @_; 
    my $reste = $texte;
    my $chaine='';

    localTrace ('debug_stript_states', ' VbCloseString ' . $reste .  "\n") ; # Erreurs::LogInternalTraces
    my $sep2=undef; # le dernier guillemet, pour reperer deux consecutifs
    #while ( $reste =~ m#(?:\A(["\x{201C}\x{201D}])(.*\C*))# )
    while ( $reste =~ m#(?:\A(["\x{201C}\x{201D}])(.*))# )
    {
        my $sep1=$1;
        $reste=$2;
        if (defined $sep2)
        {
            $chaine=$chaine.$sep2; #ou sep1?
        }
        #if ( $reste =~ m#\A(?:(.*?)(["\x{201C}\x{201D}])(.*\C*))# )
        if ( $reste =~ m#\A(?:(.*?)(["\x{201C}\x{201D}])(.*))# )
        {
            my $content=$1; 
            $sep2=$2;
            $reste=$3;
            $chaine=$chaine.$content;
        } 
        else
        {
            # Absence de guillemet fermant correspondant a l'ouvrant.
            print STDERR "ATTENTION: Absence de guillemet fermant correspondant a l'ouvrant.\n";
            $sep2=' ';
            $chaine=$chaine.$reste;
            $reste='';
            return undef;
        }
      localTrace ('debug_stript_states', ' VbCloseString ->' . $reste .  "\n") ; # Erreurs::LogInternalTraces
    }
    localTrace ('debug_stript_states', ' VbCloseString retour->' . $reste . ',' . $chaine . "\n") ; # Erreurs::LogInternalTraces
    return [$reste, $chaine];
}


my $stringid=1;
my $date_id=1;

#  According to VBLS80.doc
#                         The Microsoft Visual Basic Language Specification
#                         Version 8.0
#                         Paul Vick
#                         Microsoft Corporation
#
#   DateLiteral  ::=  #  [  Whitespace+  ]  DateOrTime  [  Whitespace+  ]  #
#   DateOrTime  ::=
#   DateValue  Whitespace+  TimeValue  |
#   DateValue  |
#   TimeValue
#   DateValue  ::=
#   MonthValue  /  DayValue  /  YearValue  |
#   MonthValue  -  DayValue  -  YearValue
#   TimeValue  ::=
#   HourValue  :  MinuteValue  [  :  SecondValue  ]  [  WhiteSpace+  ]  [  AMPM  ]
#   MonthValue  ::=  IntLiteral
#   DayValue  ::=  IntLiteral
#   YearValue  ::=  IntLiteral
#   HourValue  ::=  IntLiteral
#   MinuteValue  ::=  IntLiteral
#   SecondValue  ::=  IntLiteral
#   AMPM  ::=  AM  |  PM
#
# IntLiteral  ::=  Digit+
# Digit  ::=  0  |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  |  9
#
#White Space
#White space serves only to separate tokens and is otherwise ignored. Logical lines containing only white space are ignored. 
#Note   Line terminators are not considered white space.
#WhiteSpace  ::=
        #< Unicode blank characters (class Zs) >  |
        #< Unicode tab character (0x0009) >
sub VbSepareCodeDate($$)
{
    my ($r_dates, $code ) = @_; 
    my $datevalue = '(?:[0-9]*/[0-9]*/[0-9]*|[0-9]*-[0-9]*-[0-9]*)';
    #my $datevalue = '(?:[0-9]*/[0-9]*/[0-9]*)';
    my $timevalue = '(?:[0-9]*:[0-9]*(?::[0-9]*)?\s*(?:AM|PM)?)';
    my $reste = $code ;
    $code = '';
    while ($reste =~ m{(#\s*(?:${datevalue}|${timevalue}|${datevalue}\s*${timevalue})\s*#)(.*)} )
    {
        my $date = $1;
        $reste = $2;
        $code .= '"D'.$date_id.'"' .$reste ;
        addDateId($r_dates, $date,  'D' . $date_id) ;
        $date_id ++;
    }
    $code .= $reste ;
    return $code;
}
        #print "\x{0007}" ;


my $re_com_or_str='(?:(["\x{201C}\x{201D}])|([\'\x{2018}\x{2019}]|(?:\b[Rr][Ee][Mm]\b)))';
#my $re_not_com_or_str='(?!'.$re_com_or_str.')';
#my $re_not_com_or_str='(?:[^"\x{201C}\x{201D}\'\x{2018}\x{2019}Rr]|\B[Rr]|\b[Rr][^EeRryyp]|\b[Rr][Ee][^Mm]|\b[Rr][Ee][Mm]\B)';
#my $re_not_com_or_str='(?:[^"\x{201C}\x{201D}\'\x{2018}\x{2019}RrEeMm]|)';
sub VbSepareCodeStringComment($$$$$)
{
    my ($x, $r_dates, $r_TabString, $num, $line ) = @_; 
    $line =~ m#^(\s*)(.*)# ;
    my $indent = $1;
    my $reste = $2;
    #my $code = $reste;
    my $code = '';
    my $c2='';
    localTrace ('debug_stript_states', ' VbSepareCodeStringComment:ligne ' . $line .  "\n") ; # Erreurs::LogInternalTraces
    # \x201C : unicode left double quote
    # \x201D : unicode right double quote
    # \x2018 : unicode left single quote
    # \x2019 : unicode right single quote
    
    my $flag_needAddComment = 0;
    my $comment = undef;
    my $commentType = undef;
        
    while ( $reste =~ m#(?:["\x{201C}\x{201D}'\x{2018}\x{2019}]|(?:\b[Rr][Ee][Mm]\b))#o )
    {
        # L'expression suivante etant plutot lente, elle n'est executee que si necessaire.

      localTrace ('debug_stript_states', ' VbSepareCodeStringComment      ' . $reste .  "\n") ; # Erreurs::LogInternalTraces

    #()
    #(.*?) (2) tout ce qui est du code
    #(?:
    #   (["\x{201C}\x{201D}])    # (3) debut de chaine
    #   |(['\x{2018}\x{2019}]      # (4..) debut de commentaire
    #       |(?:\b[Rr][Ee][Mm]\s)) # (..4) debut de commentaire
    #)
    #(.*\C*) # (5) le reste (A la derniere iteration, il n'ya plus ni ", ni ')
        #$reste =~ m#\A()(.*?)(?:(["\x{201C}\x{201D}])|(['\x{2018}\x{2019}]|(?:\b[Rr][Ee][Mm]\b)))(.*\C*)#o ;
        $reste =~ m#\A()(.*?)(?:(["\x{201C}\x{201D}])|(['\x{2018}\x{2019}]|(?:\b[Rr][Ee][Mm]\b)))(.*)#o ;
        # $1 : nothing
        # $2 : before quotes or "rem"  --> code
        # $3 : double quote            --> string
        # $4 : simple quote            --> comment
        # $5 : after  quotes or "rem"  --> code or comment.
        
        if (defined $2)
        {
            # prise en compte du code
            $c2 .= $2;
        }
        if ( defined $3 )
        {
            # prise en compte du bout de chaine
            #print $num . ":"."chaine : (".$3.") " . $5 ."\n";
            my $chaine = undef;
            my $resultDeCloseString = VbCloseString($x, $stringid, $3.$5);
            return undef if (not defined $resultDeCloseString) ;
            ($reste, $chaine) = @{$resultDeCloseString} ;
            localTrace ('debug_stript_states', ' VbCloseString recup ->' . $reste . ',' . $chaine . "\n") ; # Erreurs::LogInternalTraces
            my $chid = 'ch' . $stringid;
            $c2 .= '"'. $chid .'"';
     
            $r_TabString->{$chid}=$chaine;
            $stringid++;
        }
        elsif ( defined $4 )
        {
          my $part2 = $2;
          my $part4 = $4;
          my $part5 = $5;
          my $faux_commentaire = 0;

          if (defined $part2)
          {
            if ( $part2 =~ /\[\s*$/smg )
            {
              $faux_commentaire = 1;
            }
          }

          if ($faux_commentaire == 1)
          {
            $c2 .= $part4 ;
            $reste = $part5;
          }
          else
          {
            # prise en compte du bout de commentaire
            # addCommentNode($x, $part5, $part4, $num) ;
            $flag_needAddComment = 1;
            $comment = $part5;
            $commentType = $part4;

            # RQ: dans la vue Mix, tous les commentaires multilignes sont mis au format
            # monoligne, et les commentaires "//" sont transformes en "/* ... */".
            # Pour cette raison, les eventuelles sequences "/*" ou "*/" qui traineraient dans

			# set to empty means end of the loop !!!
            $reste = '';
          }
        }
        $code = $c2;
    }
    
    $code .= $reste;
    {
        if (not ($code =~ m#^\s*$# ))
        {
            $code = VbSepareCodeDate($r_dates, $code);
            addCodeLine($x, $code, $indent, $num);
        }
        
        if ($flag_needAddComment) {
			addCommentNode($x, $comment, $commentType, $num) ;
		}
    }
  return 0;
}

sub VbKeepCodeFromBuffer ($$$)
{
    my ($filename, $text_buffer, $options) = @_; 

    my %TabString = ();
    my $r_TabString = \%TabString ;

    configureLocalTraces('VBKeepCode', $options);                       # Erreurs::LogInternalTraces
    #print STDERR "debug_stript_states" . "\n" ;                         # Erreurs::LogInternalTraces
    localTrace (undef, ' essai localTrace '  .  "\n") ;                 # Erreurs::LogInternalTraces
    localTrace ('debug_stript_states', ' essai localTrace '  .  "\n") ; # Erreurs::LogInternalTraces
    #print STDERR "debug_stript_states" . "\n" ;                         # Erreurs::LogInternalTraces

    #my $line_number = undef; # Erreurs::LogInternalTraces
    my $num=1; #On numerote les lignes a partir de 1
    my %h =();
    my $r=\%h;
    $r->{'code'} = '';
    $r->{'comment'} = '';
    $r->{'MixBloc'} = '';
    $r->{'string'} = $r_TabString ;
    my $c = $text_buffer;
    my %dates=();
    my $r_dates= \%dates;
    #while ($c =~ m/(.*)(?:\n|(\Cz*)\n)/igm)
    while ($c =~ m/(.*)\n/igm) 
    { 
      my $line = $1; 
      #NB: on suppose qu'il n'y a pas de caracteres malformes. recuperer le \C
      my $resultSeparation = VbSepareCodeStringComment($r, $r_dates, $r_TabString, $num, $line);
      return undef if (not defined $resultSeparation);
      $r->{'code'} .= "\n" ;
      $r->{'comment'} .= "\n" ;
      $r->{'MixBloc'} .= "\n" ;
      $num++;
    }
    return $r;
}



our $VB8_re_KeyWords = '\b(?:' .
    'AddHandler|AddressOf|Alias|And|AndAlso|As|Boolean|ByRef|Byte|ByVal|' .
    'Call|Case|Catch|CBool|CByte|CChar|CDate|CDbl|CDec|Char|CInt|Class|CLng|' .
    'CObj|Const|Continue|CSByte|CShort|CSng|CStr|CType|CUInt|CULng|CUShort|' .
    'Date|Decimal|Declare|Default|Delegate|Dim|DirectCast|Do|Double|' .
    'Each|Else|ElseIf|End|EndIf|Enum|Erase|Error|Event|Exit|' .
    'False|Finally|For|Friend|Function|Get|GetType|Global|GoSub|GoTo|' .
    'Handles|If|Implements|Imports|In|Inherits|Integer|Interface|Is|IsNot|' .
    'Let|Lib|Like|Long|Loop|' .
    'Me|Mod|Module|MustInherit|MustOverride|MyBase|MyClass|' .
    'Namespace|Narrowing|New|Next|Not|Nothing|NotInheritable|NotOverridable|' .
    'Object|Of|On|Operator|Option|Optional|' .
    'Or|OrElse|Overloads|Overridable|Overrides|' .
    'ParamArray|Partial|Private|Property|Protected|Public|' .
    'RaiseEvent|ReadOnly|ReDim|REM|RemoveHandler|Resume|Return|' .
    'SByte|Select|Set|Shadows|Shared|Short|Single|' . 
    'Static|Step|Stop|String|Structure|Sub|SyncLock|' .
    'Then|Throw|To|True|Try|TryCast|TypeOf|UInteger|ULong|UShort|Using|Variant|' .
    'Wend|When|While|Widening|With|WithEvents|WriteOnly|Xor' .
    ')\b' ;

#   TypeCharacter  ::=
#           IntegerTypeCharacter  |
#           LongTypeCharacter  |
#           DecimalTypeCharacter  |
#           SingleTypeCharacter  |
#           DoubleTypeCharacter  |
#           StringTypeCharacter
#   IntegerTypeCharacter  ::=  %
#   LongTypeCharacter  ::=  &
#   DecimalTypeCharacter  ::=  @
#   SingleTypeCharacter  ::=  !
#   DoubleTypeCharacter  ::=  #
#   StringTypeCharacter  ::=  $

my $VB8_TypeCharacterD = '[%&@!#$]' ;




#   AlphaCharacter  ::=
#           < Unicode alphabetic character (classes Lu, Ll, Lt, Lm, Lo, Nl) >
#   NumericCharacter  ::=  < Unicode decimal digit character (class Nd) >
#   CombiningCharacter  ::=  < Unicode combining character (classes Mn, Mc) >
#   FormattingCharacter  ::=  < Unicode formatting character (class Cf) >
#   UnderscoreCharacter  ::=  < Unicode connection character (class Pc) >
#   IdentifierOrKeyword  ::=  Identifier  |  Keyword
my $VB8_AlphaCharacterC = '\p{Lu}|\p{Ll}|\p{Lt}|\p{Lm}|\p{Lo}|\p{Nl}' ;
my $VB8_NumericCharacterC = '\p{Nd}' ;
my $VB8_CombiningCharacterC = '\p{Mn}|\p{Mc}' ;
my $VB8_FormattingCharacterC = '\p{Cf}' ;
my $VB8_UnderscoreCharacterC = '\p{Pc}' ;

#   IdentifierCharacter  ::=
#           UnderscoreCharacter  |
#           AlphaCharacter  |
#           NumericCharacter  |
#           CombiningCharacter  |
#           FormattingCharacter
my $VB8_IdentifierCharacterC = "${VB8_UnderscoreCharacterC}|${VB8_AlphaCharacterC}|" .
        "${VB8_NumericCharacterC}|${VB8_CombiningCharacterC}|${VB8_FormattingCharacterC}" ;

#   IdentifierName  ::=  IdentifierStart  [  IdentifierCharacter+  ]
#   IdentifierStart  ::=
#           AlphaCharacter  |
#           UnderscoreCharacter  IdentifierCharacter
my $VB8_IdentifierStartD = '(?:' . "${VB8_AlphaCharacterC}|(?:${VB8_UnderscoreCharacterC})${VB8_IdentifierCharacterC}" . ')' ;
my $VB8_IdentifierNameD =  '(?:' . "${VB8_IdentifierStartD}(?:${VB8_IdentifierCharacterC}" . ')*)'   ;

#   Identifier  ::=
#           NonEscapedIdentifier  [  TypeCharacter  ]  |
#           Keyword  TypeCharacter  |
#           EscapedIdentifier
#   NonEscapedIdentifier  ::=  < IdentifierName but not Keyword >
#   EscapedIdentifier  ::=  [  IdentifierName  ] 
my $VB8_EscapedIdentifierD =  "\x{007b}${VB8_IdentifierNameD}\x{007d}"   ;
my $VB8_NonEscapedIdentifierD =  "(?!${VB8_re_KeyWords})${VB8_IdentifierNameD}"   ;
our $VB8_Identifier =  "(?:${VB8_NonEscapedIdentifierD}${VB8_TypeCharacterD}?|" .
                         "${VB8_re_KeyWords}${VB8_TypeCharacterD}|" .
                         "${VB8_EscapedIdentifierD})"   ;



1;
