package PlSql::SynthCount;

use strict;
use warnings;
use Erreurs;

# Description: Module de comptage des mots (halstead)
#
# Compatibilite: PL-SQL

sub CountVG($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;
  my $status = 0;

  my @IdentList = (
	  #If
	  Ident::Alias_Base_If(),
	  Ident::Alias_Base_Elsif(),

	  # Case 
          Ident::Alias_CaseWhen(),

	  # Default
          Ident::Alias_Default(),

	  # Catch
          Ident::Alias_WhenOthers(),
          Ident::Alias_ExceptionWhen(),

	  # Boucles
	  Ident::Alias_Base_Loop(),
	  #Ident::Alias_Base_For(),  # Already counted with Loop !!!
	  Ident::Alias_Base_Forall(),
	  #Ident::Alias_Base_While(), # Already counted with loop !!!
	  #Ident::Alias_Base_Do(), # not a ¨PlSql Keyword !!!

	  Ident::Alias_FunctionImplementations(),
	  Ident::Alias_ProcedureImplementations(),
	  Ident::Alias_TriggerImplementations() );

    my $nb_VG = 0;
    my $VG__mnemo = Ident::Alias_VG();

    for my $ident (@IdentList) {
      if ( ! defined $compteurs->{$ident}) {
        $nb_VG = Erreurs::COMPTEUR_ERREUR_VALUE;
        print "Counter not available for VG synthesis : $ident\n";
	last;
      }
    }

    if ( $nb_VG != Erreurs::COMPTEUR_ERREUR_VALUE) {
      # IF & LOOP are counted two times (IF .. END IF // LOOP .. END LOOP)
      $nb_VG += int ($compteurs->{Ident::Alias_Base_If()} / 2) ;
      $nb_VG += int ($compteurs->{Ident::Alias_Base_Loop()} / 2) ;

      # elsif 
      $nb_VG += int ($compteurs->{Ident::Alias_Base_Elsif()} ) ;

      # case 
      $nb_VG += int ($compteurs->{Ident::Alias_CaseWhen()} ) ;
  
      # default 
      $nb_VG += int ($compteurs->{Ident::Alias_Default()} ) ;

      # catch (When)
      $nb_VG += int ($compteurs->{Ident::Alias_ExceptionWhen()} ) ;

      # catch (When Others)
      # Should not be counted because "WHEN OTHERS" is already counted in Ident::Alias_ExceptionWhen !!
      #$nb_VG += int ($compteurs->{Ident::Alias_WhenOthers()} ) ;
      
      # routines
      $nb_VG += int ($compteurs->{Ident::Alias_FunctionImplementations()} ) ;
      $nb_VG += int ($compteurs->{Ident::Alias_ProcedureImplementations()} ) ;
      $nb_VG += int ($compteurs->{Ident::Alias_TriggerImplementations()} ) ;
    }


    $status |= Couples::counter_add($compteurs, $VG__mnemo, $nb_VG);

  return $status;
}




1;

