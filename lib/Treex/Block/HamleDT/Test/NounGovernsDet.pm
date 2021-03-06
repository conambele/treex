package Treex::Block::HamleDT::Test::NounGovernsDet;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $afun = $node->afun();
    $afun = '' if(!defined($afun));
    # Exclude ExD nodes from the test. The node they should really depend on is not present in the tree.
    return 1 if($afun eq 'ExD');
    # Exclude apposition from the test. It is strange anyway if it depends on a determiner but then it is mainly problem of the main noun phrase that probably also depends on the same determiner.
    # One example that I have seen in Danish is actually correct: "et af selskaber" = "one of companies". The numeral "et" is correctly the head in this case.
    return 1 if($afun eq 'Apposition');
    my $parent = $node->parent();
    if(defined($parent))
    {
        my $pos = $node->get_iset('pos');
        # TODO: should the determiners (adjtype = 'det') be included as well?
        $pos = 'art' if($node->get_iset('adjtype') eq 'art');
        my $prn = $node->get_iset('prontype');
        # Two pronouns, one modifying the other, are not error (da: "det andet").
        # Thus we want to catch only real nouns/adjectives below.
        $pos = 'pronoun' if($prn ne '');
        my $ppos = $parent->get_iset('pos');
        # TODO: should the determiners (adjtype = 'det') be included as well?
        $ppos = 'art' if($parent->get_iset('adjtype') eq 'art');
        my $pprn = $parent->get_iset('prontype');
        $ppos = 'pronoun' if($pprn ne '');
        if($pos =~ m/^(noun|adj)$/ && $ppos =~ m/^(pronoun|num|art)$/)
        {
            $self->complain($node, $parent->form().'->'.$node->form());
        }
        elsif($ppos =~ m/^(noun|adj)$/ && $pos =~ m/^(pronoun|num|art)$/)
        {
            $self->praise($node);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::NounGovernsDet

Determiners and numerals depend on nouns, not vice versa (as in Danish Dependency Treebank).
Similarly, adjectives should not depend on determiners or numerals.
This test will also catch certain Czech examples from PDT (numeral is child in "čtyři lidé", "s pěti lidmi" but it is parent in "pět lidí").

Danish also makes adjectives and genitive nouns heads of noun phrases.
Such cases are harder to detect because we cannot exclude that a noun really will modify an adjective (cf. Czech "bledý strachy").

=back

=cut

# Copyright 2013 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

