package Treex::Tool::PhraseParser::Alpino;

use Moose;
use Treex::Core::Common;
use ProcessUtils;

# Used to parse Alpino output. This is quite ugly, but I want to avoid code duplication
use Treex::Block::Read::Alpino; 

has '_twig'               => ( is => 'rw' );
has '_alpino_readhandle'  => ( is => 'rw' );
has '_alpino_writehandle' => ( is => 'rw' );
has '_alpino_pid'         => ( is => 'rw' );

sub BUILD {

    my $self      = shift;
    my $tool_path = 'installed_tools/parser/Alpino';
    my $exe_path  = require_file_from_share("$tool_path/bin/Alpino");
    
    $tool_path = $exe_path; # get real tool path (not relative to Treex share)
    $tool_path =~ s/\/bin\/.*//;
    $ENV{ALPINO_HOME} = $tool_path; # set it as an environment variable to be passed to Alpino

    #TODO this should be done better
    my $redirect = Treex::Core::Log::get_error_level() eq 'DEBUG' ? '' : '2>/dev/null';

    # Force line-buffering of Alpino's output (otherwise it will hang)
    my @command = ( 'stdbuf', '-oL', $exe_path, 'end_hook=xml_dump', '-parse' );

    $SIG{PIPE} = 'IGNORE';    # don't die if parser gets killed
    my ( $reader, $writer, $pid ) = ProcessUtils::bipipe_noshell( ":encoding(utf-8)", @command );
    
    $self->_set_alpino_readhandle($reader);
    $self->_set_alpino_writehandle($writer);
    $self->_set_alpino_pid($pid);

    $self->_set_twig( XML::Twig::->new() );

    return;
}

sub parse_zones {
    my ( $self, $zones_rf ) = @_;

    my $writer = $self->_alpino_writehandle;
    my $reader = $self->_alpino_readhandle;

    foreach my $zone (@$zones_rf) {

        # Take the (tokenized) sentence
        my @forms = map { $_->form } $zone->get_atree->get_descendants( { ordered => 1 } );

        # Have Alpino parse the sentence
        print $writer join( " ", @forms ) . "\n";
        my $line = <$reader>;

        if ( $line !~ /^<\?xml/ ) {
            log_fatal( 'Unexpected Alpino input: ' . $line );
        }
        my $xml = $line;
        while ( $line and $line !~ /^<\/alpino_ds/ ) {
            $line = <$reader>;
            $xml .= $line;
        }

        # Create a p-tree out of Alpino's output
        if ( $zone->has_ptree ) {
            $zone->remove_tree('p');
        }
        my $proot = $zone->create_ptree;
        $self->_twig->setTwigRoots(
            {
                alpino_ds => sub {
                    my ( $twig, $xml ) = @_;
                    $twig->purge;
                    $proot->set_phrase('top');
                    foreach my $node ( $xml->first_child('node')->children('node') ) {
                        Treex::Block::Read::Alpino::create_subtree( $node, $proot );
                    }
                }
            }
        );
        $self->_twig->parse($xml);
    }

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseParser::Alpino

=head1 DESCRIPTION

A Treex bipipe wrapper for the Dutch Alpino parser. Uses L<Treex::Block::Read::Alpino>
to convert the parser output.

=head1 NOTES

Probably works on Linux only (due to the usage of the C<stdbuf> command to prevent buffering
of Alpino's output). No checks or automatic downloads are done for the rest of the Alpino 
distribution, just for the main executable.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.