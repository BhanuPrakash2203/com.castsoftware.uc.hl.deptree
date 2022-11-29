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

# Composant: Plugin
#----------------------------------------------------------------------#
# DESCRIPTION: Composant de preprocessing du code source.
#----------------------------------------------------------------------#


package Prepro;

# modules importes
use strict;
use warnings;
use Lib::Log;

# prototypes publics
sub Prepro($$$);

# prototypes prives
sub BuiltPreproView($$$$);
sub isDefined($$);
sub isTrue($$);
sub EvalTest($$);
sub EvalDefine($);



my @stack = ();
my %TabDefined =  ( 'false' => 1);     # false est defini par defaut.
my %TabDefValue = ( 'false' => 0 );    # la valeur de false est 0.

my $NewLine = '';
my $LOC_removed = 0;


#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction concatene les nouveau element qui doivent figurer dans
#              la vue prepro.
#-------------------------------------------------------------------------------

sub BuiltPreproView($$$$) {
  my ($r_viewPrepro, $r_instrPrepro, $r_code, $status) = @_ ;

  my $nb_LOC_removed = 0;

  $$r_instrPrepro =~ s/[^\n]//g ;

  if ($status ne 'T') {
	$nb_LOC_removed = () = $$r_code =~ /\S+[ \t]*(?:\n|\z)/mg;
    $$r_code =~ s/[^\n]//g ;
  }

  $$r_viewPrepro .= $NewLine.$$r_instrPrepro . $$r_code ;

  return $nb_LOC_removed;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction permettant de tester si un symbol de preprocessing est
#              deja defini.
#-------------------------------------------------------------------------------

sub isDefined($$) {
  my ($symbol, $neg) = @_ ;

  my $value = 0;

  if ( $symbol !~ /^d+$/ ) {
    if ( exists $TabDefined{$symbol} ) {
      $value = $TabDefined{$symbol}
    }
    else {
      # Choix d'une valeur par defaut (1 pour considerer comme defini, 0 pour considerer comme non defini.
      if ( $neg == 0 ) {
        $value = 1;
  
        # Si on choisit de considerer le symbol comme defini, il faut lui attribuer une valeur par defaut.
        $TabDefValue{$symbol} = 1;
      }
      else {
        $value = 0;
      }
      $TabDefined{$symbol} = $value;
    }
  }

  return $value;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction permettant de tester si la valeur d'un symbol de preprocessing est TRUE.
#-------------------------------------------------------------------------------

sub isTrue($$) {
  my ($symbol, $neg) = @_ ;

  my $value = 0;

  if ( $symbol !~ /^\d+$/ ) {

    if ( exists $TabDefValue{$symbol} ) {
      $value = $TabDefValue{$symbol};

      # ROBUSTESSE : cas d'une valeur associee alors que le symbole est indefini.
      if (( ! exists $TabDefined{$symbol} ) || ( $TabDefined{$symbol} == 0 )) {
        Lib::Log::ERROR("$symbol ident cannot be in the same time undefined and having a value.");
        $TabDefined{$symbol} = 1;
      }

      if ( $value !~ /^\d+$/ ) {
        Lib::Log::WARNING("Non numeric define value ($value) for ident $symbol. TRUE is assumed by default.");
        $value = 1;
      }
    }
    else {
      # Choix d'une valeur par defaut.
      # Choisir 0 si le symbol est explicitement marque comme "non defini"
      if ( (exists ($TabDefined{$symbol})) && ($TabDefined{$symbol} == 0) ) {
        $value = 0;
      }
      else {
        # sinon choisir 1 pour faire en sorte que le test soit TRUE, et marquer le symbole comme defini.
        $value = 1;
        $TabDefined{$symbol} = 1;
      }
      $TabDefValue{$symbol} = $value;
    }
  }
  else {
    $value = $symbol;
  }

  if ($value == 0) {
    return 0;
  }
  else {
    return 1;
  }
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction permettant d'avaluer si une expression de directive de compilation
#              conditionnelle est TRUE ou FALSE. 
#              Les symboles non definis se voient attribuer une valeur par defaut.
#-------------------------------------------------------------------------------

sub EvalTest($$) {
  my ($directive, $expression) = @_ ;

  my $res = 'U';

  if ( $expression =~ /\A([\s!]*)(defined\b)?[\s\(]*(\w*)[\s\)?]*\Z/ ) {
  
    my ( $neg, $def, $symbol) = ($1, $2 , $3);

    my $negExpr = 0;
    if ($neg =~ /!/) { $negExpr = 1; }

    my $negInstr = 0;
    if ( ($directive eq 'ifndef') || ($directive eq 'elifndef' )) { $negInstr = 1; }
  
    my $toBeNegated = 0;
    if ( ($negExpr==1) || ($negInstr==1) ) { $toBeNegated = 1; }


    if ( ($directive eq 'if') || ($directive eq 'elif') || ($directive eq 'elsif')) {
      if ( isTrue($symbol, $toBeNegated)) {
        $res = 'T';
      }
      else {
        $res = 'F';
      }
    }
    elsif (($directive eq 'ifdef') || ($directive eq 'ifndef') || ($directive eq 'elifdef') || ($directive eq 'elifndef')) {
      if ( isDefined($symbol, $toBeNegated)) {
        $res = 'T';
      }
      else {
        $res = 'F';
      }
    }
    else {
      Lib::Log::WARNING("Unknow compilation directive : $directive");
      return 'U';
    }

    if ($toBeNegated==1) {
      if ( $res eq 'T') {
        $res = 'F';
      }
      else {
        $res = 'T';
      }
    }
    return $res;
  }
  else {
    # Code pour renvoyer T si l'expression est trop complexe ...
    return 'T';

    # Code pour ne pas rendre de resultat si une expression est trop complexe ...   #bt_filter_line
    #print STDERR "[EvalSymbol] Expression trop complexe : $expression\n";          #bt_filter_line
    #return "U";                                                                    #bt_filter_line
  }

}

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction permettant d'avaluer une directive #define
#-------------------------------------------------------------------------------
sub EvalDefine($) {
  my ($expression) = @_ ;

  my $res = 0;
  my $symbol;
  if ( $expression =~ /\A\s*(\w+)\(/s ) {
    $symbol = $1;
    # Les macros parametrees ne doivent pas entraver l'analyse ...
    # On ne met donc pas $res a 0 pour ne pas partir en erreur, et on definit quand meme la
    # macro a 1, au cas ou ...
    $res = 1;
    $TabDefValue{$symbol} = 1;
    $TabDefined{$symbol} = 1;
  }
  elsif ( $expression =~ /\A\s*(\S+)\s*(.*)/s ) {
    $symbol = $1;
    my $definition = $2;

    if ( $definition eq '' ) {
      # Par defaut, un simple define est positionne a 1.
      $TabDefValue{$symbol} = 1;
    }
    else {
      my ($value) = $definition =~ /\s*([^\s]*)\s*/s;
      $TabDefValue{$symbol} = $value;
    }
    $TabDefined{$symbol} = 1;
    $res = 1;
  }
  
  return $res;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de selection du code conditionnel.
#-------------------------------------------------------------------------------

sub Prepro($$$) {
  my ($fichier, $r_code, $vue) = @_ ;
  my $ret = 0;

  # On dupplique le buffer code pour pouvoir le modifier. Cette modification est necessaire dans le cas ou la premiere instruction
  # du code n'est pas une directive de complilation. 
  # Il existe certainement une optimisation dans l'implementation du traitement qui dispenserait d'effectuer cette dupplication.
  # A ameliorer donc ...
  my $code = $$r_code;

  if ( ! defined $code ) {
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  $vue->{'prepro'} = '';
  $LOC_removed = 0;
  Lib::Log::INFO("Creation of the 'prepro' view ...");

  my ($head) = $code =~ /\A([^#]*)/s;
  $code =~ s/\A([^#]*)//s;

  if (defined $head) {
    # Tout ce qu'il y a avant la premiere directive de compilation doit etre recopie sans traitement.
    $vue->{'prepro'} .= $head ;
  }

  my @Tdirective = split (/(?:\n|\A)[ \t]*#/, $code);

  my $NotPreprocessable = 0;
  my $level = 0;
  my $type = 'root';
  my $status = 'T';

  push (@stack, [$level, $type, $status]);

  foreach my $CodeCond (@Tdirective) {

    if ( $CodeCond ne '') {
      my ($instrPrepro, $directive, $expression, $prgCode) = $CodeCond =~ /(\s*(\w*)((?:[^\n]*\\\n)*[^\n]*[^\\]?\n?))(.*)/s ;

      if ( $directive eq 'define' ) {
        #--------------------------------------
        # Definition du symbole ...
        #--------------------------------------

        if ( $status eq 'T' ) {
          if (  EvalDefine($expression) == 0 ) {
            $NotPreprocessable = 1;
            Lib::Log::ERROR("Too complex macro definition : $expression");
            last;
          }
        }
      }
      elsif ( ($directive eq 'ifdef') || ($directive eq 'ifndef') || ($directive eq 'if') ) {
            # STATUS
            if ( $status eq 'T' ) {
              $status = EvalTest($directive, $expression);

              if ($status eq 'U') {
                $NotPreprocessable = 1;
                Lib::Log::ERROR("Conditional expression evluation error.");
                last;
              }
            }
            else {
              $status = 'FF';
            }

            # LEVEL
            $level++;
            
            # TYPE
            $type = $directive;

            push (@stack, [$level, $type, $status]);
      }
          
      elsif (($directive eq 'elif') || ($directive eq 'elsif') || ($directive eq 'elifdef') || ($directive eq 'elifndef')){

            # STATUS
            if ( ($status eq 'T') || ($status eq 'FF') ) {
              $status = 'FF';
            }
            else {
              $status = EvalTest($directive, $expression);

              if ($status eq 'U') {
                $NotPreprocessable = 1;
                Lib::Log::ERROR("Conditional expression evluation error.");
                last;
              }
            }

            # LEVEL : les "else" n'introduisent pas un nouveau niveau.
            pop @stack;
            
            # TYPE
            $type = $directive;

            push (@stack, [$level, $type, $status]);
      }
      elsif ($directive eq 'else') {
        if ( ($type eq 'if') || ($type eq 'elsif') || ($type eq 'elif') || ($type eq 'ifdef') || ($type eq 'ifndef')) {

          # STATUS
          if ( ( $status eq 'T' ) ||  ($status eq 'FF' )) {
            $status = 'FF';
          }
          else { 
            $status = 'T';
          }

          #TYPE
          $type = $directive;

          #LEVEL : ne change pas.

          pop @stack;                               # on depile le "if" precedent.
          push (@stack, [$level, $type, $status]);  # on empile le "else".
        }
        else {
          Lib::Log::ERROR("#else can not follow $type.");
          $NotPreprocessable = 1;
          last;
        }
      }
      elsif ($directive eq 'endif') {
        # on depile le niveau courant.
        pop @stack;

        # On se met a jour par rapport au niveau precedent, mais sans le depiler vraiment ...
        ($level, $type, $status) = @{ pop @stack };
         push (@stack, [$level, $type, $status]);
      }
      $LOC_removed += BuiltPreproView(\$vue->{'prepro'}, \$instrPrepro, \$prgCode, $status);
      $NewLine = "\n";
    }
  }

  if ($NotPreprocessable == 1) {
    $vue->{'prepro'} = undef;
    Lib::Log::WARNING("Aborting prepro view building ...\n");
  }
  else {
    Lib::Log::INFO("prepro view built by removing $LOC_removed lines of code !");
  }

  return $ret;

}

#-------------------- MACROS ------------------

sub getParamList($) {
  my $params = shift;
  my @T_params = ();
  my $level = 0;
  my $p = "";

  return [] if !defined $params;

  return [] if $params =~ /^\(\s*\)/m;

  $params =~ /\G\(/gc;
  while ($params =~ /(,|\(|\)|[^,\(\)]*)/gc) {
    if ((($1 eq ",") || ($1 eq ")")) && ($level <= 0)) {
      #print "MACRO PARAM : $p\n";
      push @T_params, $p;
      $p = "";
    }
    elsif ($1 eq "(") {
      $level++;
      $p.=$1;
    }
    elsif ($1 eq ")") {
      $level--;
      $p.=$1;
    }
    else {
      $p.=$1;
    }
  }

  return \@T_params;
}

sub evaluateMacro($$$) {
  my $macroName = shift;
  my $def = shift;
  my $call_params = shift;

  my $T_call_params = getParamList($call_params);
  my $T_def_params = $def->{'params'};

  if ((scalar @$T_def_params) != (scalar @$T_call_params)) {
    my $expectedNumberParams = scalar @$T_def_params;
    my $numberParams = scalar @$T_call_params;

    # FIXME : If there are several macro, choose the one who has the right number of parameters !!!
    print "WARNING : bad number of argument for macro $macroName ($numberParams but expected: $expectedNumberParams)\n";
  }

  my $idx = 0;
  my $expand = $def->{'expr'};
  while ((defined $T_def_params->[$idx]) && (defined $T_call_params->[$idx])) {
    $expand =~ s/$T_def_params->[$idx]/$T_call_params->[$idx]/g;
    $idx++;
  }
  Lib::Log::INFO("MACRO EXPANSION : $macroName ~~~~> $expand\n");
  return $expand;
}

sub expandMacros($$) {
  my $macros = shift;
  my $view = shift;
  my %lineShift = ();

  for my $file (sort keys %{$macros}) {
    my $fileMacros = $macros->{$file};
    for my $macro (sort keys %{$fileMacros}) {
      # name of macro is uppercased
      $$view =~ s/\b$macro\b[ \t]*(\((?:(?>[^\(\)]+)|(?1))*\))?/&evaluateMacro($macro, $fileMacros->{$macro}, $1) /ge;
    }
  }
  return \%lineShift;
}

my $macroListH;
sub searchMacro($$)
{
  my $fileDesc = shift;
  my $options = shift;
  
  my $fileName0 = AnalyseOptions::GetSourceDirectory($options) . ${$fileDesc->{'name'}};
  my $fileName = \$fileName0;
  
  if ($$fileName =~ /\.h.*$/m) {
    my $ret = open(FILE_H, '<', $$fileName);

	if (! $ret) {
		Lib::Log::ERROR("Warning : unable to read file $$fileName");
		return;
	}

    local $/ = undef;
    my $buf = <FILE_H>;
    #close FILE_H;

    $fileDesc->{'content'} = \$buf;
    $fileDesc->{'handler'} = *FILE_H;

    # $1 = name
    # $2 = params
    # $3 = content
    while ($buf =~ /^\s*#\s*define\s+([\w]+)(?:\s*\(([\w\,\s\.]*)\))?((?:.*\\\s*\n)*.*$)/mg) {
      my @args = split(/,/, $2) if (defined $2);
      if (defined $2 and $2 ne "..." and $2 ne ""){
        foreach my $arg (@args) {
          $arg =~ s/\s+//g;
        }
      }
      else{
        @args = undef;
      }

      # FIXME : should issue a warning if the macro is redefining a C++ keyword.

print STDERR "$$fileName is defining $1\n";

      # macro with parameters
      if (defined $2 and defined $3) {
        my $macroName = $1;

        if (! exists $macroListH->{$$fileName}->{$macroName}->{'params'})
        {
          $macroListH->{$$fileName}->{$macroName}->{'params'} = \@args;
        }
        $macroListH->{$$fileName}->{$macroName}->{'expr'} = $3;
      }
      elsif (defined $2) {
        my $macroName = $1;

        if (! exists $macroListH->{$$fileName}->{$macroName}->{'params'})
        {
          $macroListH->{$$fileName}->{$macroName}->{'params'} = \@args;
        }
        $macroListH->{$$fileName}->{$1}->{'expr'} = "";
      }
      elsif (defined $3) {
        $macroListH->{$$fileName}->{$1}->{'params'} = [];
        $macroListH->{$$fileName}->{$1}->{'expr'} = $3;
      }
      else {
        $macroListH->{$$fileName}->{$1}->{'params'} = [];
        $macroListH->{$$fileName}->{$1}->{'expr'} = "";
      }
    }
  }
}

sub GetMacros{
  return $macroListH;
}

sub removeSystemCompilerFeature{
  my $macros = shift;
  my $view = shift;

  my $keywordSystem = qr/(?:_)?_pragma/i;

  for my $file (sort keys %{$macros}) {
    my $fileMacros = $macros->{$file};
    for my $macro (sort keys %{$fileMacros}) {
      my $quoted_substring = quotemeta($fileMacros->{$macro}->{'expr'});
      if ($quoted_substring =~ /$keywordSystem/ig)
      {
        $$view =~ s/$quoted_substring//g;
      }
    }
  }
}

#-----------------------------------------------------------------------

use constant NODE_PATH 		=> 2;
use constant NODE_CHILDREN 	=> 3;
use constant NODE_FILE 		=> 4;

my %DIRECTORIES = ();
my $TREE_DIR = [
	undef, 	# 0 - name
	undef, 	# 1 - parent node
	undef, 	# 2 - path
	{},		# 3 - children
	{}		# 4 - files
];

sub newNode($$) {
	my $name = shift;
	my $parent = shift;
	return [$name, $parent, (defined $parent->[NODE_PATH] ? $parent->[NODE_PATH] . "/$name" : $name), {}];
}

sub addIncludeDir($) {
	my $file = shift;
	
	my ($path, $filename) = $file =~ /^(.*[\\\/]?)([^\\\/]*)$/m;
	$path =~ s/[\\]/\//g;	# replace "\" with "/"
	$path =~ s/[\/]\s*$//m;	# remove trailing "/"
	$path =~ s/^\w:\///g;	# remove drive (for windows path)
	$path =~ s/^\///g;		# root "/" (for unix like path)
	
	my @dirs = split '/', $path;
	my $tree = $TREE_DIR;
	
	# add to tree
	while (scalar @dirs) {
		my $dir = shift @dirs;
		
		if (exists $tree->[NODE_CHILDREN]->{$dir}) {
			$tree = $tree->[NODE_CHILDREN]->{$dir};
		}
		else {
			$tree->[NODE_CHILDREN]->{$dir} = newNode($dir, $tree);
			$tree = $tree->[NODE_CHILDREN]->{$dir};
		}
	}
	
	$tree->[NODE_FILE]->{$filename} = {};
	
	# add to path DB
	my $subpath = $path;
	while ($subpath ne "") {
		$DIRECTORIES{$subpath} = $tree;
		
		$subpath =~ s/^[^\/]+\/*//m;
	}
}

sub searchInclude($) {
	my $fullname = shift;
	my ($path, $file) = $fullname =~ /^(.*[\\\/]?)([^\\\/]*)$/m;
	$path =~ s/[\\]/\//g;	# replace "\" with "/"
	$path =~ s/[\/]\s*$//m;	# remove trailing "/"
	$path =~ s/^\w:\///g;	# remove drive (for windows path)
	$path =~ s/^\///g;		# root "/" (for unix like path)
	
	my $dirNode = $DIRECTORIES{$path};
	if (defined $dirNode) {
		my $filedescr = $dirNode->[NODE_FILE]->{$file};
		return $filedescr;
	}
	
	Lib::Log::WARNING("INCLUDE $fullname not found");
	return undef;
}

sub manageIncludes($) {
	my $views = shift;
	
	my $code = \$views->{"code_with_prepro"};
	
	while ($$code =~ /#\s*include\s*(?:<([^>]+)|["']([^"']+))/g) {
		if (defined $1) {
			#print "INCLUDE $1\n";
			searchInclude($1);
		}
		elsif (defined $2) {
			#print "INCLUDE $2\n";
			searchInclude($2);
		}
	}
}

sub printDirectories() {
	my $nb =0;
	for my $dir (sort keys %DIRECTORIES) {
		print STDERR "DIR = $dir --> ".$DIRECTORIES{$dir}->[NODE_PATH]."\n";
		$nb++;
	}
	print STDERR "TOTAL DIR = $nb\n";
}

1;
