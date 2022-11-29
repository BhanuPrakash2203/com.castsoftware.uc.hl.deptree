package TraceDetect;

# prototypes prives
sub DumpTraceDetect ($$$$);                                             # traces_filter_line
sub TraceOutToFile ($$);                                                # traces_filter_line

# traces_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Calcule le numero de ligne
#-------------------------------------------------------------------------------
sub CalcLineMatch($$)
{
    my ($c, $pos_c) = @_;
    my $line_number = substr($c, 0, $pos_c) =~ tr{\n}{\n};
    $line_number++;

    return $line_number;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Ecrit le fichier detect
#-------------------------------------------------------------------------------
sub DumpTraceDetect($$$$)
{
    my ($fichier, $mnemo, $trace_detect, $options) = @_;

    return if ($fichier eq DUMMYFILENAME);

    return if (defined $options->{'--Mnemo'} and ($options->{'--Mnemo'} ne $mnemo));

    my $base_filename = $fichier;
    $base_filename =~ s{.*/}{};

    # 'output/dump/' .
    my $base_out = '';

    if (defined $options->{'--dir'})
    {
        $base_out = $options->{'--dir'} . '/';
    }

    my $outputFilename =  $base_out . $base_filename. '.' . $mnemo . '.detect.txt' ;

#    print STDERR "\n\noutputFilename = $outputFilename\n";

    # format unix
    open my $ouputFile, ">:raw", $outputFilename or die "cannot write to $outputFilename $!";

    print $ouputFile $trace_detect;

    close $ouputFile;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Enregistre le texte dans un fichier
#-------------------------------------------------------------------------------
sub TraceOutToFile($$)
{
    my ($fichier, $texte) = @_;

    my $dummy_filename = DUMMYFILENAME;

    return if ($fichier =~ /^$dummy_filename/);

    my $outputFilename = $fichier . ".trace_out_to_file.txt";

    # format UNIX
    open my $ouputFile, ">:raw", $outputFilename or die "cannot write to $outputFilename $!";

    print $ouputFile $texte;

    # print STDERR "TraceOutToFile $outputFilename\n";

    close $ouputFile;
}

# traces_filter_end

1;
