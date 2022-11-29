package framework::composer;

use strict;
use warnings;

use JSON;
use framework::dataType;
use framework::detections;
use framework::Logs;
use Lib::Sources;

sub parseComposerLock() {
    my %H_dependencies_lock;
    # scan composer.lock if exists and create a hash with name and version component
    my $content_lock = Lib::Sources::getFileContent('.\composer.lock');
    if (! defined $content_lock) {
        framework::Logs::Warning("Unable to read composer.lock for json inspection purpose.\n");
        return undef;
    }

    my $decoded_json_lock = eval{ decode_json($$content_lock) };
    my $dependencies_lock = $decoded_json_lock->{'packages'};
    # array ref
    for my $component (@{$dependencies_lock}) {
        my $depName = $component->{'name'};
        my $depVersion = $component->{'version'};
        $depVersion =~ s/^v//m;
        if (defined $depName && defined $depVersion) {
            $H_dependencies_lock{$depName} = $depVersion;
        }
        else {
            framework::Logs::Warning("dependencies component data structure of $depName in composer.lock is not recognized\n");
        }
    }

    return \%H_dependencies_lock;
}

sub parseComposerJson($$$$) {
    my $dependencies = shift;
    my $H_dependencies_lock = shift;
    my $context = shift;
    my $H_DatabaseName = shift;

    # hash ref
    for my $dependName (keys %$dependencies) {
        my $dependVersion;
        my $depDef = $dependencies->{$dependName};

        if (exists $H_dependencies_lock->{$dependName}) {
            $dependVersion = $H_dependencies_lock->{$dependName};
        }
        else {
            $dependVersion = $depDef;
        }

        push @{$context->{'$depList'}}, { 'name' => $dependName, 'version' => $dependVersion };

        my $jsonItem = framework::detections::getEnvItem($dependName, $dependVersion, $context->{'jsonDB'}, 'json', $context->{'jsonPath'}, $H_DatabaseName);
        if (defined $jsonItem) {
            push @{$context->{'itemDetection'}}, $jsonItem;
        }
    }

    return $context;
}

1;
