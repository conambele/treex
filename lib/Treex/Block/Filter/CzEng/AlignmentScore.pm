package Treex::Block::Filter::CzEng::AlignmentScore;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );

extends 'Treex::Block::Filter::CzEng::Common';

has aliscore_file => (
    isa           => 'Str',
    is            => 'ro',
    required      => 1,
    documentation => 'file with logs of word alignment score for each sentence'
);

sub process_document {
    my ( $self, $document ) = @_;
    open( my $scores_hdl, $self->{aliscore_file} ) or log_fatal $!;

    for my $bundle ( $document->get_bundles() ) {
        chomp( my $score = <$scores_hdl> );
        log_fatal "Error reading file $self->{aliscore_file}" if ! defined $score;
        my @en = $bundle->get_zone('en')->get_atree->get_descendants;
        my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;
        my $max_len = max( scalar @en, scalar @cs );
        my @bounds = ( -50, -25, -10, -5, -2, -1 );

        $self->add_feature( $bundle, "word_alignment_score="
            . $self->quantize_given_bounds( $score, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::AlignmentScore

=back

A filtering feature computed from word alignment score as output by Giza++.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
