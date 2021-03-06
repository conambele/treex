package Treex::Block::T2A::EU::GenerateWordforms;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Flect::FlectBlock';

has '+model_file' => ( default => 'data/models/flect/model-eu.pickle.gz');

has '+features_file' => ( default => 'data/models/flect/model-eu.features.yml' );


sub process_atree {
    my ( $self, $aroot ) = @_;

    my @anodes = $aroot->get_descendants( { ordered => 1 } );
    
    my @forms = $self->inflect_nodes(@anodes);

    for ( my $i = 0; $i < @anodes; ++$i ) {
        if ( not defined( $anodes[$i]->form ) ) {
            $anodes[$i]->set_form( $forms[$i] );
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::GenerateWordforms

=head1 DESCRIPTION

Generating word forms using the Flect tool. Contains pre-trained model settings for Spanish.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
