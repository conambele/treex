#!/usr/bin/env perl
use strict;
use warnings;

use Treex::Core::Common;
use Treex::Core::Resource;
use Treex::Tool::Memcached::Memcached;

my $action = shift @ARGV;

print STDERR "Action: $action\n";

if ( $action eq "start" ) {
    Treex::Tool::Memcached::Memcached::start_memcached(@ARGV);
}
elsif ( $action eq "load" ) {
    Treex::Tool::Memcached::Memcached::load_model(@ARGV);
}
elsif ( $action eq "process" ) {
    process(@ARGV);
}
elsif ( $action eq "missing" ) {
    missing(@ARGV);
}
elsif ( $action eq "stats" ) {
    Treex::Tool::Memcached::Memcached::print_stats();
}
elsif ( $action eq "stop" ) {
    Treex::Tool::Memcached::Memcached::stop_memcached();
}
else {
    help();
}

sub process
{
    my ($file) = @_;

    if ( !Treex::Tool::Memcached::Memcached::get_memcached_hostname() ) {
        log_fatal "Memcached is not running";
    }

    open( my $fh, "<", $file ) or log_fatal $! . " ($file)";
    while (<$fh>) {
        chomp;

        if (/(TrFAddVariants|TrLAddVariants|TrFRerank2)/) {
            my @parts         = split(/\t/);
            my $required_file = Treex::Core::Resource::require_file_from_share( $parts[1], 'Memcached' );
            my $class         = "";
            if ( $required_file =~ /\.maxent\./ ) {
                $class = 'TranslationModel::MaxEnt::Model';
            }
            elsif ( $required_file =~ /\.nb\./ ) {
                $class = 'TranslationModel::NaiveBayes::Model';
            }
            elsif ( $required_file =~ /\.static\./ ) {
                $class = 'TranslationModel::Static::Model';
            }
            else {
                log_warn "Unknown model file for $file\n";
                next;
            }
            Treex::Tool::Memcached::Memcached::load_model( $class, $required_file );

        }
    }
    close($fh);

    return;
}

sub missing
{
    my ($file) = @_;

    if ( !Treex::Tool::Memcached::Memcached::get_memcached_hostname() ) {
        log_fatal "Memcached is not running";
    }

    open( my $fh, "<", $file ) or log_fatal $! . " ($file)";
    while (<$fh>) {
        chomp;

        if (/(TrFAddVariants|TrLAddVariants|TrFRerank2)/) {
            my @parts         = split(/\t/);
            my $required_file = $ENV{TMT_ROOT} . "/share/" . $parts[1];
            if ( !Treex::Tool::Memcached::Memcached::contains($required_file) ) {
                print $required_file, "\n";
            }
        }
    }
    close($fh);

    return;
}

sub help
{
    print <<'DOC';
USAGE
./memcached.pl command [options]

./memcached.pl start memory
    Executes memcached with XGB of memory. If more memory will be required
    memcached will be terminated.
    If server is already running, nothing happens.
    ./memcached.pl start 10
    
./memcached.pl stop
    Terminates memcached.
    
./memcached.pl stats
    Prints usage statistics.

./memcached.pl load package file
    Loads model [file] to memcached.
    If file is already loaded, it does nothing.
    ./memcached.pl load \
        TranslationModel::MaxEnt::Model \
        ...../tlemma_czeng12.maxent.10000.100.2_1.pls.gz

./memcached.pl process file
    Processes file generated by treex --dump_required_files.
    In current implementation loads only translation models.
    
./memcached.pl missing file
    Prints path of models from file generated by treex --dump_required_files
    which are not loaded.
    In current implementation loads only translation models.

DOC

    return;
}
