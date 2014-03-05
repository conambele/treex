package Treex::Block::SemevalABSA::Coord;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @ands = grep { $_->afun eq 'Coord' && $_->lemma eq 'and' } $atree->get_descendants;

    for my $and ( @ands ) {
        my @nodes = grep { $_->afun ne m/^Aux/ } $and->get_children;
        my $total = $self->combine_polarities(
            map { $self->get_aspect_candidate_polarities( $_ ) }
            grep { $self->is_aspect_candidate( $_ ) }
            @nodes
        );
        if ( $total eq '+' || $total eq '-' ) {
            map { $self->mark_node( $_, "coord$total" ) } @nodes;
        }
    }

    return 1;
}

1;

#   Vzdycky, když najdes aspekt, vsechno, co je snim v koordinaci je taky aspekt.
#
#              Pr. The excellent mussels, puff pastry, goat cheese and salad.