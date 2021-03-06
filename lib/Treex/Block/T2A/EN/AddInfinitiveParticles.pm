package Treex::Block::T2A::EN::AddInfinitiveParticles;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddInfinitiveParticles';

override 'works_as_conj' => sub {
    my ($self, $particle) = @_;
    return not $particle eq 'to';
}; 

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddInfinitiveParticles

=head1 DESCRIPTION

The particle 'to' is added to English infinitives. Other prepositions
in constructions such as "It's time for him to go home." are added
as well.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
