package Treex::Block::HamleDT::Transform::PrepositionDownward;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Transform::BaseTransformer';

use Treex::Tool::ATreeTransformer::DepReverser;

sub BUILD {
    my ($self) = @_;

    $self->set_transformer(
        Treex::Tool::ATreeTransformer::DepReverser->new(
            {
                subscription     => $self->subscription,
                nodes_to_reverse => sub {
                    my ( $child, $parent ) = @_;
                    return ( $parent->afun eq 'AuxP' && $child->afun !~ /^Aux/ );
                },
                move_with_parent => sub {
                    my ($node) = @_;
                    return $node->afun =~ /^Aux[YP]$/;
                },
                move_with_child => sub {1},
            }
            )
        )
}

1;

=over

=item Treex::Block::HamleDT::Transform::PrepositionDownward

Move a preposition below the node (usually a noun or a pronoun) which
it has governed. In the case of complex prepositions, the additional
AuxP children are kept below the main AuxP node.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

