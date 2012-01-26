package Treex::Block::A2T::CS::MarkRelClauseCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my $antec;

    # relative pronouns without "coz"
    if ( $t_node->get_lex_anode && $t_node->get_lex_anode->tag =~ /^.[149JK\?]/ ) {

        my $relclause = $t_node->get_clause_head;        
        if (!$relclause->is_root){ # probably due to parsing errors, this happens from time to time
            my @e_parents = $relclause->get_eparents( { or_topological => 1 } );
            if ( scalar @e_parents > 1 ) {
    
                my @depth_sorted = sort { $a->get_depth <=> $b->get_depth } @e_parents;
                $antec = shift @depth_sorted;
                while ( ( grep { !$_->is_descendant_of($antec) } @depth_sorted ) > 0 ) {
                    $antec = $antec->get_parent;
                }
    
            }
            else {
                $antec = $e_parents[0];
            }
            # cancel the link if it points to a verb
            #if (defined $antec && $antec->gram_sempos eq "v") {
            #    $antec = undef;
            #}
        }
    }

    # relative pronoun "coz"
    elsif ( $t_node->get_lex_anode && $t_node->get_lex_anode->tag =~ /^.E/ ) {

        my $parent = $t_node->get_parent;
        if (   defined $parent
            && defined $parent->get_parent &&
            defined $parent->get_parent->get_lex_anode &&
            $parent->get_parent->get_lex_anode->lemma =~ /^[,-]$/ &&
            defined $parent->get_left_neighbor
            )
        {
            $antec = $parent->get_left_neighbor;
        }
        else {
            my @nodes = grep {$_->ord < $t_node->ord} 
                $t_node->get_root->get_descendants({ordered => 1});
            my @clause_heads = grep {$_->is_clause_head} @nodes;

            if (@clause_heads > 0) {
                $antec = pop @clause_heads;
            }



            #my $doc   = $t_node->get_document;
            #my @trees = map {
            #    $_->get_tree(
            #        $t_node->language, $t_node->get_layer, $t_node->selector
            #        )
            #} $doc->get_bundles;

            #my $tree_idx = List::MoreUtils::first_index { $_ == $t_node->get_root } @trees;

            #if ( $tree_idx > 0 ) {
            #    my $prev_tree = $trees[ $tree_idx - 1 ];

            #    my @prev_verbs = sort { $a->get_depth <=> $b->get_depth }
            #        (
            #        grep { defined $_->get_lex_anode && $_->get_lex_anode->tag =~ /^V/ }
            #            $prev_tree->descendants
            #        );

                #$antec = $prev_verbs[0];

                #my @prev_words = $prev_tree->descendants({ordered => 1});
                #$antec = first { defined $_->get_lex_anode
                #    && $_->get_lex_anode->tag =~ /^V/ } reverse @prev_words;
            #}

        }

    }

    if ( defined $antec && !$antec->is_root ) {    # klauze se nasla a tudiz to nedobehlo az ke koreni
        $t_node->set_deref_attr( 'coref_gram.rf', [$antec] );
    }
}

1;

# prakticky identicke s anglickym protejskem, mozna by to chtelo predelat na genericky blok!!!

=over

=item Treex::Block::A2T::CS::MarkRelClauseCoref

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected in SCzechT trees
and store into the C<coref_gram.rf> attribute.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
