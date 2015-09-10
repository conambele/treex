package Treex::Core::Phrase::NTerm;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;

extends 'Treex::Core::Phrase::BasNTerm';



has 'head' =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Phrase',
    required => 1,
    writer   => '_set_head',
    reader   => 'head'
);



#------------------------------------------------------------------------------
# After the object is constructed, this block makes sure that the head refers
# back to it as its parent.
#------------------------------------------------------------------------------
sub BUILD
{
    my $self = shift;
    if(defined($self->head()->parent()))
    {
        confess("The head already has another parent");
    }
    $self->head()->_set_parent($self);
}



#------------------------------------------------------------------------------
# Sets a new head child for this phrase. The new head must be already a child
# of this phrase. The old head will become an ordinary non-head child.
#------------------------------------------------------------------------------
sub set_head
{
    my $self = shift;
    my $new_head = shift; # Treex::Core::Phrase
    confess('Dead') if($self->dead());
    my $old_head = $self->head();
    return if ($new_head == $old_head);
    # Remove the new head from the list of non-head children.
    # (The method will also verify that it is defined and is my child.)
    $self->_remove_child($new_head);
    # Add the old head to the list of non-head children.
    $self->_add_child($old_head);
    # Finally, set the new head, using the private bare setter.
    $self->_set_head($new_head);
}



#------------------------------------------------------------------------------
# Replaces the head by another phrase. This is used when we want to transform
# the head to a different class of phrases. The replacement must not have a
# parent yet.
#------------------------------------------------------------------------------
sub replace_core_child
{
    my $self = shift;
    my $old_child = shift; # Treex::Core::Phrase
    my $new_child = shift; # Treex::Core::Phrase
    confess('Dead') if($self->dead());
    $self->_check_old_new_child($old_child, $new_child);
    # We have not checked yet whether the old child is the head.
    if($old_child != $self->head())
    {
        confess("The replacement child is not my head");
    }
    $old_child->_set_parent(undef);
    $new_child->_set_parent($self);
    $self->_set_head($new_child);
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase::NTerm

=head1 SYNOPSIS

  use Treex::Core::Document;
  use Treex::Core::Phrase::Term;
  use Treex::Core::Phrase::NTerm;

  my $document = new Treex::Core::Document;
  my $bundle   = $document->create_bundle();
  my $zone     = $bundle->create_zone('en');
  my $root     = $zone->create_atree();
  my $node     = $root->create_child();
  my $tphrase  = new Treex::Core::Phrase::Term ('node' => $node);
  my $ntphrase = new Treex::Core::Phrase::NTerm ('head' => $tphrase);

=head1 DESCRIPTION

C<NTerm> is a nonterminal C<Phrase>. It contains (refers to) one or more child
C<Phrase>s.
See L<Treex::Core::Phrase> for more details.

=head1 ATTRIBUTES

=over

=item head

A sub-C<Phrase> of this phrase that is at the moment considered the head phrase (in the sense of dependency syntax).
Head is a special case of child (sub-) phrase. The (one) head must always exist; other children are optional.

=back

=head1 METHODS

=over

=item $phrase->set_head ($child_phrase);

Sets a new head child for this phrase. The new head must be already a child
of this phrase. The old head will become an ordinary non-head child.

=item $phrase->replace_core_child ($old_head, $new_head);

Replaces the head by another phrase. This is used when we want to transform
the head to a different class of phrases. The replacement must not have a
parent yet.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
