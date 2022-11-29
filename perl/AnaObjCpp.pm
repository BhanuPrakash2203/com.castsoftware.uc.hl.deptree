package AnaObjCpp;
# les modules importes
use strict;
use warnings;

use Erreurs;
use StripCpp;
use AnaUtils;
use AnaConfiguration_H_C_HPP_CPP;
use CountC_CPP_FunctionsMethodsAttributes;
use Cpp::CppClassDef;
use ObjC::ParseObjC;
use Vues; # dumpvues_filter_line
use Timeout;
use IsoscopeDataFile;
use CppKinds;

# prototypes publics
sub Strip ($$$$);
sub Count ($$$$$);
sub Analyse ($$$$);
sub FileTypeRegister ($);

# prototypes prives

#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement du strip
#-------------------------------------------------------------------------------
sub Strip ($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;
  my $status = 0;

  eval
  {
    $status = StripCpp::StripCpp ($fichier, $vue, $options, $compteurs);
  };

  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Strip: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  if ( Erreurs::isAborted($status) )
  {
    # si le strip genere une erreur, on ne continue pas
    return $status;
  }

  return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement du parsing
#-------------------------------------------------------------------------------

my %H_ClassDescr = ();

sub resetClassDescr() {
   %H_ClassDescr = ();
}

sub getClassDescr($) {
  my $class = shift;

  if (! exists $H_ClassDescr{$class}) {
    my %emptyH = ();
    $emptyH{'nb_methods'} = 0;
    $emptyH{'nb_static_methods'} = 0;
    $emptyH{'nb_members'} = 0;
    $emptyH{'nb_static_members'} = 0;
    $H_ClassDescr{$class} = \%emptyH;
    
  }
  return  $H_ClassDescr{$class};
}

sub isCopyConstructor($$) {
  my $data = shift;
  my $class_name = shift;

  if ($data->{'b_ctor'}) {

    if (defined $data->{'item'}) {
      if ($data->{'item'} =~ /\b$class_name\s*\(\s*(?:const)?\s*&?\s*$class_name\s*&?\s*\w+\s*\)/s ) {
	 return 1;
      }
    }
    else {
      print "ERROR: prototype does not exist for function/method !!?\n";
    }
  }
  return 0;
}

sub isDefaultConstructor($$) {
  my $data = shift;
  my $class_name = shift;

  if ($data->{'b_ctor'}) {

    if (defined $data->{'item'}) {
      if ($data->{'item'} =~ /\b$class_name\s*\(\s*\)/s ) {
	 return 1;
      }
    }
    else {
      print "ERROR: prototype does not exist for function/method !!?\n";
    }
  }
  return 0;
}

sub isCopyAssignmentOperator($$) {
  my $data = shift;
  my $class_name = shift;

  if (defined $data->{'item'}) {
    if ($data->{'item'} =~ /\boperator=\s*\(\s*(?:const|volatile)?\s*(?:\bconst|\bvolatile)?\s*\b$class_name\s*[&*]?\s*\w*\)/s ) {
      return 1;
    }
  }
  else {
    print "ERROR: prototype does not exist for function/method !!?\n";
  }
  return 0;
}

sub consolidateInfoByClass($) {
  my $views = shift;

  resetClassDescr();

  if (defined $views->{'parsed_code'}) {
      my $root = $views->{'parsed_code'};

      # record all informations class per class.
      for my $item (@$root)
      {
	  my $data = $item->[1];
          # consider only items that are inside a class interface definition.
          if ( defined ($data->{'b_item_inside_class'}) && ($data->{'b_item_inside_class'} == 1) ) { 
	      my $class_scope = $data->{'scope_class'};

	      if (defined $class_scope) {
   	          my $classDescr = getClassDescr($class_scope);

		  if ( ($item->[0] == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE) ||
		      ($item->[0] == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE) )  {

                     # inc number of methods other than constructor or destructor.
		     if (($data->{'b_ctor'} == 0) && ($data->{'b_dtor'} == 0)) {
                         $classDescr->{'nb_methods'}++;
		         if ($data->{'item'} =~ /\bstatic\b/s ) {
                             $classDescr->{'nb_static_methods'}++;
		         }
		     }

		     # class is Abstract
                     if ( $data->{'b_pure_virtual'}) {
		         $classDescr->{'abstract'} = 1;
		     }

		     # class has at leat one virtual method
		     if ( ! (($data->{'b_ctor'}) && ($data->{'b_dtor'})) &&
			     ($data->{'b_virtual'})) {
                         $classDescr->{'virtual_meth'} = 1;
		     }

		     # Class has a virtual destructor.
                     if (($data->{'b_dtor'}) && ($data->{'b_virtual'})) {
		         $classDescr->{'virtual_dtor'} = 1;
		     }

		     # class defines a copy constructor
		     if ( isCopyConstructor($data, $class_scope)) {
		         $classDescr->{'user_copy_ctor'} = $item;
		     }

		     # class defines a copy constructor
		     elsif ( isDefaultConstructor($data, $class_scope)) {
		         $classDescr->{'user_default_ctor'} = $item;
		     }

		     # class defines a copy assignment operator.
		     elsif ( isCopyAssignmentOperator($data, $class_scope)) {
		         $classDescr->{'copy_assign_op'} = $item;
		     }

		     # class defines an ampersand operator.
		     elsif ( $data->{'item'} =~ /\boperator&\s*\(\s*\)/s) {
		         $classDescr->{'ampersand_op'} = $item;
		     }

		     # class defines an comma operator.
		     elsif ( $data->{'item'} =~ /\boperator,/s) {
		         $classDescr->{'comma_op'} = $item;
		     }

		     # class defines an logical AND operator.
		     elsif ( $data->{'item'} =~ /\boperator&&/s) {
		         $classDescr->{'logical_and_op'} = $item;
		     }

		     # class defines an logical OR operator.
		     elsif ( $data->{'item'} =~ /\boperator\|\|/s) {
		         $classDescr->{'logical_or_op'} = $item;
		     }

		     # class defines a destructor
		     elsif ($data->{'b_dtor'}) {
		         $classDescr->{'user_dtor'} = $item;
		     }
                 }

                 elsif ( ($item->[0] == PARSER_CPP_DECLARATION_VARIABLE ) ||
		         ($item->[0] == PARSER_CPP_DECLARATION_STRUCT ) ||
		         ($item->[0] == PARSER_CPP_DECLARATION_VARIABLE_PTR_SUR_FONCTION ) ) {
	             $classDescr->{'nb_members'}++;
	             if ($data->{'item'} =~ /\bstatic\b/) {
	                 $classDescr->{'nb_static_members'}++;
	             }
	         }
                 elsif ($item->[0] == PARSER_CPP_DECLARATION_CLASS ) {
		     if ($data->{'item'} =~ /:/) {
		         $classDescr->{'derived'} = 1;
		     }
		 }
             }
         }
      }
  }

  $views->{'class_def'} = \%H_ClassDescr;
  return 0;
}

sub Parse($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;
  my $status = 0;
  eval
  {
    $status |= CountC_CPP_FunctionsMethodsAttributes::Parse ($fichier, $vue, $compteurs, $options);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Parsing: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  else {
    # Make a synthesis overview for all files with some information of the
    # Cpp Parser.
    
    $status |= Cpp::CppClassDef::consolidateInfoByClass($vue);
    # Parse ObjC code with new parser ...
    eval
    {
      $status |= ObjC::ParseObjC::Parse ($fichier, $vue, $compteurs, $options);
    };
    if ($@ )
    {
      Timeout::DontCatchTimeout();   # propagate timeout errors
      print STDERR "Error when parsing ObjC syntax for ObjCpp file: $@ \n" ;
      $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
    }
  }

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement des comptages
#-------------------------------------------------------------------------------
sub Count ($$$$$)
{
  my ($fichier, $vue, $options, $compteurs, $r_TableFonctions) = @_;
  my $status = 0;
  $status |= AnaUtils::Count ($fichier, $vue, $options, $compteurs, $r_TableFonctions );
  return $status;
}

# Ces variables doivent etre globales dans le cas nominal (dit nocrashprevent)
my $firstFile = 1;
my ($r_TableMnemos, $r_TableFonctions );
my $confStatus = 0;


# Module d'enregistrement des compteurs pour la sortie .csv
sub FileTypeRegister ($)
{
  my ($options) = @_;

  if ($firstFile != 0)
  {
        $firstFile = 0;

        #------------------ Chargement des comptages a effectuer -----------------------

        my $ConfigModul='ObjCpp_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("ObjCpp", $r_TableMnemos);
        }
  }
}


#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement de l'analyse
#-------------------------------------------------------------------------------
sub Analyse ($$$$)
{
  my ($fichier, $vues, $options, $couples) = @_;
  my $status = 0;

  FileTypeRegister ($options);

  $status |= $confStatus;

  my $analyseur_callbacks = [ \&Strip, \&Parse, \&Count, $r_TableFonctions ];
  $status |= AnaUtils::Analyse($fichier, $vues, $options, $couples, $analyseur_callbacks) ;

  if (($status & ~Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES))
  {
    # continue si Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES seul
    my $message = 'Echec de pre-traitement dans un comptage';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'AnaCpp', $message);
  }

  return $status;
}

1;
