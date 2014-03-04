package Treex::Block::SemevalABSA::FirstNounAboveSubjAdjAdv;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @adj_adv = grep { 
        ($_->get_attr('tag') =~ m/^JJ/ || $_->get_attr('tag') =~ m/^RB/)
        && is_subjective( $_ )
    } $atree->get_descendants;

    my @predicates;

    for my $node (@adj_adv) {
        my $polarity = get_polarity( $node );
        my $tag = ($node->get_attr('tag') =~ m/^JJ/ ? "adj" : "adv");
        my $parent = $node->get_parent;
        while (! $parent->is_root ) {
            if ($parent->get_lemma eq "be") {
                push @predicates, {
                    node => $parent,
                    polarity => $polarity,
                    tag => $tag,
                };
            } else {
                $parent = $parent->get_parent;
            }
        }
    }

    for my $pred (@predicates) {
        my ($subj, @rest) = grep {
            $_->get_attr('afun') eq 'Sb'
        } $pred->{node}->get_children;
        if ($subj) {
            mark_node( $subj, "vbnm_sb_" . $pred->{tag} . $pred->{polarity} );
        } else {
            log_warn "No subject found for predicate: " . $pred->{node}->get_attr('id');
        }

        if (@rest) {
            log_warn "More than one subject found for predicate: " . $pred->{node}->get_attr('id');
        }
    }
}

1;

# Pokud jsem jmenna cast verbonominalniho predikatu a jsem hodnotici adjektivum,
# je aspektem podmet slovesa (sponove vzdy „to be“), na kterem visim. (pozor!
# sloveso nemusi byt vždy PRED – zavisle klauze!)
# 
#   Pr. The staff ACT was horrible RSTR.
# 
#     The perk was great, The fried rice is amazing. Etc.
# 
# Pokud jsem jmenna cast verbonominalniho predikatu a jsem hodnotici adverbium,
# je aspektem podmet slovesa, na kterem visim.
# 
#   Pr. The service ACT is fast MANN.
