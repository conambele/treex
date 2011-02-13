package TCzechT_to_TCzechA::Choose_mlemma_for_PersPron;

use 5.008;
use strict;
use warnings;
use utf8;
use Readonly;

use base qw(TectoMT::Block);

my %subpos_person_2_mlemma =
    (
    qw(H1) => qw(já),
    qw(H2) => qw(ty),
    qw(H3) => qw(on),
    qw(P1) => qw(já),
    qw(P2) => qw(ty),
    qw(P3) => qw(on),
    qw(S1) => qw(můj),
    qw(S2) => qw(tvůj),
    qw(S3) => qw(jeho),
    qw(53) => qw(on),
    );

# (Subpos . person) -> m-lemma mapping
# When person is not known, let's guess 3.
#<<< no perltidy
Readonly my %M_LEMMA_FOR => (
    H1 => 'já',  H2 => 'ty',   H3 => 'on',   'H.' => 'on',   #short forms (mě,mi,ti,...)
    P1 => 'já',  P2 => 'ty',   P3 => 'on',   'P.' => 'on',   #normal forms
    S1 => 'můj', S2 => 'tvůj', S3 => 'jeho', 'S.' => 'jeho', #possessive
    '53' => 'on',   # pronoun "on" after preposition (něj, něho,...)
    '8.' => 'svůj', # possesive reflexive (possessor is the subject of the clause)
    '6.' => 'se',   # reflexive "se" long form  (sebe, sobě, sebou)
    '7.' => 'se',   # reflexive "se" short form (se,si)
);
#>>>

sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $a_node ( $bundle->get_tree('TCzechA')->get_descendants() ) {
        my $subpos = $a_node->get_attr('morphcat/subpos') || '.';
        my $person = $a_node->get_attr('morphcat/person') || '.';
        my $pronoun_mlemma = $M_LEMMA_FOR{ $subpos . $person };
        next if !$pronoun_mlemma;
        $a_node->set_attr( 'm/lemma', $pronoun_mlemma );
        $a_node->set_attr( 'm/form',  $pronoun_mlemma );
    }
    return;
}

1;

__END__

# mapa ziskana btredim skriptem z a-roviny pdt2.0 takto:
# ntred -TNe 'my $tag=$this->attr("m/tag"); my $l=$this->attr("m/lemma");if ($l!~/,[th]/ and $tag=~/^P(.).....([1-3])/) {$shorttag=$1.$2;$l=~s/[_-].+//;print "   qw($shorttag) => qw($l),\n"}' | sort | uniq
# +rucni doplneni

=over

=item TCzechT_to_TCzechA::Choose_mlemma_for_PersPron

Attribute C<m/lemma> of a-nodes corresponding to #PersPron is
set accordingly to subpos and person of the pronoun.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
