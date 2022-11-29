BEGIN
{
  my $rep = $0;
  # FIXME: ce repertoire devrait preceder le repertoire Cobol.
  # FIXME: peut etre faisable en chargeant les modules dynamiquement (incident 24)

  if ( $rep =~ m{[\/\\]} )
  {
    $rep =~ s{(.*)[\/\\][^\/\\]+}{$1};
  }
  else
  {
    $rep = '.' ;
  }
  push @INC, $rep;
}

use Progression;


  my $ProgressionFilename='progression.txt';
  my $progression = new Progression ($ProgressionFilename);


  my @list1 = ( [ 17, 4, 'toto.cpp'],
                [ 2317, 3, 'titi/toto.c++'] 
              );
  my @list2 = ( [ 17, 4, 'include/toto.hpp'],
                [ 2317, 3, 'include/titi/toto.h++'] 
              );

  my @unusedlistname  =  qw(
./dcop/client/dcopclient.c
./dcop/client/dcopobject.c
./dcop/client/dcopref.c
./dcop/dcopc.c
./dcop/dcopserver_shutdown.c
./dcop/KDE-ICE/accept.c
./dcop/KDE-ICE/authutil.c
./dcop/KDE-ICE/connect.c
./dcop/KDE-ICE/error.c
./dcop/KDE-ICE/getauth.c
./dcop/KDE-ICE/globals.c
./dcop/KDE-ICE/iceauth.c
./dcop/KDE-ICE/listen.c
./dcop/KDE-ICE/listenwk.c
./dcop/KDE-ICE/locking.c
./dcop/KDE-ICE/misc.c
./dcop/KDE-ICE/ping.c
./dcop/KDE-ICE/process.c
./dcop/KDE-ICE/protosetup.c
./dcop/KDE-ICE/register.c
./dcop/KDE-ICE/replywait.c
./dcop/KDE-ICE/setauth.c
./dcop/KDE-ICE/shutdown.c
./dcop/KDE-ICE/transport.c
./dcop/KDE-ICE/watch.c
./dcop/KDE-ICE/Xtrans.c
./dcop/KDE-ICE/Xtranssock.c
./dcop/KDE-ICE/Xtransutil.c);
  my @list3 = map { [1000, 0, $_] } @unusedlistname;


  my %appli = ( 'AnaCpp' => \@list1,  
                'AnaHpp' => \@list2,
                'test' => \@list3);

  my $total = 4;


  $progression->ProgressBeginAppli( $total);

  for my $ana ( keys (%appli) )
  {
    my $list = $appli{$ana};

    $progression->ProgressBeginList( scalar @$list, $ana);

    for my $file (@$list)
    {
      $progression->ProgressBeginFile( $file->[2]);
      sleep(1);
      $progression->ProgressLineNumberFile($file->[0]);
      sleep(2);
      $progression->ProgressEndFile( $file->[1]);
    }

    $progression->ProgressEndList( 0 );
  }

  $progression->ProgressEndAppli( 0 );



