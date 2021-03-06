package Treex::Block::HamleDT::BG::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'bg::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Bulgarian tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    $self->process_auxiliary_particles($root);
    $self->process_auxiliary_verbs($root);
    $self->mark_deficient_clausal_coordination($root);
    $self->check_afuns($root);
}

#------------------------------------------------------------------------------
# Try to convert dependency relation tags to analytical functions.
# http://www.bultreebank.org/dpbtb/
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        if ( $deprel eq 'ROOT' )
        {
            if ( $node->get_iset('pos') eq 'verb' || $self->is_auxiliary_particle($node) )
            {
                $node->set_afun('Pred');
            }
            else
            {
                $node->set_afun('ExD');
            }
        }
        elsif ( $deprel =~ m/^x?subj$/ )
        {
            $node->set_afun('Sb');
        }

        # comp ... Complement (arguments of: non-verbal heads, non-finite verbal heads, copula)
        # nominal predicate: check that the governing node is a copula
        elsif ( $deprel eq 'comp' )
        {

            # If parent is form of the copula verb 'to be', this complement shall be 'Pnom'.
            # Otherwise, it shall be 'Obj'.
            my $parent = $node->parent();
            my $verb   = $parent;

            # If we have not processed the auxiliary particles yet, the parent is the particle and not the copula.
            if ( $self->is_auxiliary_particle($parent) )
            {
                my $lvc = $self->get_leftmost_verbal_child($parent);
                if ( defined($lvc) )
                {
                    $verb = $lvc;
                }
            }

            # \x{435} = 'e' (cs:je)
            # \x{441}\x{430} = 'sa' (cs:jsou)
            # \x{441}\x{44A}\x{43C} = 'săm' (cs:jsem)
            # \x{431}\x{44A}\x{434}\x{435} = 'băde' (cs:bude)
            if ( $node != $verb && $verb->form() =~ m/^(\x{435}|\x{441}\x{430}|\x{431}\x{44A}\x{434}\x{435}|\x{441}\x{44A}\x{43C})$/ )
            {
                $node->set_afun('Pnom');
            }
            else
            {
                $node->set_afun('Obj');
            }
        }

        # obj ... Object (direct argument of a non-auxiliary verbal head)
        # indobj ... Indirect Object (indirect argument of a non-auxiliary verbal head)
        # object, indirect object or complement
        elsif ( $deprel =~ m/^((ind)?obj)$/ )
        {
            $node->set_afun('Obj');
        }

        # adjunct: free modifier of a verb
        # xadjunct: clausal modifier
        elsif ( $deprel eq 'xadjunct' && $node->match_iset( 'pos' => 'conj', 'conjtype' => 'sub' ) )
        {
            $node->set_afun('AuxC');
        }

        # marked ... Marked (clauses, introduced by a subordinator)
        elsif ( $deprel eq 'marked' )
        {
            $node->set_afun('Adv');
        }
        elsif ( $deprel =~ m/^x?adjunct$/ )
        {
            $node->set_afun('Adv');
        }

        # Pragmatic adjunct is an adjunct that does not change semantic of the head. It changes pragmatic meaning. Example: vocative phrases.
        elsif ( $deprel eq 'pragadjunct' )
        {

            # PDT: AuxY: "příslovce a částice, které nelze zařadit jinam"
            # PDT: AuxZ: "zdůrazňovací slovo"
            # The only example I saw was the word 'păk', tagged as a particle of emphasis.
            $node->set_afun('AuxZ');
        }

        # xcomp: clausal complement
        # If the clause has got a complementizer ('that'), the complementizer is tagged 'xcomp'.
        # If there is no complementizer (such as direct speech), the root of the clause (i.e. the verb) is tagged 'xcomp'.
        elsif ( $deprel eq 'xcomp' )
        {
            if ( $node->get_iset('pos') eq 'verb' )
            {
                $node->set_afun('Obj');
            }
            else
            {
                $node->set_afun('AuxC');
            }
        }

        # negative particle 'ne', modifying a verb, is an adverbiale
        elsif ( $deprel eq 'mod' && lc( $node->form() ) eq "\x{43D}\x{435}" )
        {
            $node->set_afun('Adv');
        }

        # mod: modifier (usually of a noun phrase)
        # xmod: clausal modifier
        elsif ( $deprel =~ m/^x?mod$/ )
        {
            $node->set_afun('Atr');
        }

        # clitic: often a possessive pronoun ('si', 'ni', 'j') attached to noun, adjective or pronoun => Atr
        # sometimes a reflexive personal pronoun ('se') attached to verb (but the verb is in a nominalized form and functions as subject!)
        elsif ( $deprel eq 'clitic' )
        {
            if ( $node->match_iset( 'prontype' => 'prs', 'poss' => 'poss' ) )
            {
                $node->set_afun('Atr');
            }
            else
            {
                $node->set_afun('AuxT');
            }
        }

        # The conjunction 'i' can serve emphasis ('even').
        # If it builds coordination instead, its afun will be corrected later.
        elsif ( $deprel eq 'conj' && $node->form() eq 'и' )
        {
            $node->set_afun('AuxZ');
            $node->wild()->{coordinator} = 1;
        }
        elsif ( $deprel eq 'punct' )
        {

            # PDT: AuxX: "čárka (ne však nositel koordinace)"
            # PDT: AuxG: "jiné grafické symboly, které neukončují větu"
            if ( $node->form() eq ',' )
            {
                $node->set_afun('AuxX');
            }
            else
            {
                $node->set_afun('AuxG');
            }
        }

        # Assign pseudo-afuns to coordination members so that all nodes are guaranteed to have an afun.
        # These will hopefully be corrected later during coordination restructuring.
        elsif ( $deprel eq 'conjarg' )
        {
            $node->set_afun('CoordArg');
            $node->wild()->{conjunct} = 1;
            # Fix error in data: conjunction labeled as conjunct.
            if($node->match_iset('pos' => 'conj', 'conjtype' => 'coor'))
            {
                my $rn = $node->get_right_neighbor();
                if($rn && $rn->conll_deprel() eq 'conjarg')
                {
                    $node->set_afun('AuxY');
                    $node->wild()->{coordinator} = 1;
                    $node->wild()->{conjunct} = 0;
                }
            }
        }
        elsif ( $deprel eq 'conj' )
        {
            $node->set_afun('AuxY');
            $node->wild()->{coordinator} = 1;
        }
        elsif ( $deprel =~ m/^x?prepcomp$/ )
        {
            $node->set_afun('PrepArg');
        }
    }

    # Make sure that all nodes now have their afuns.
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if ( !$afun )
        {
            log_warn( "Missing afun for node " . $node->form() . "/" . $node->tag() . "/" . $node->conll_deprel() );
        }
    }

    # Once all nodes have hopefully their afuns, prepositions must delegate their afuns to their children.
    # (Don't do this earlier. If appositions are postpositions, we would be copying afuns that don't exist yet.)
    $self->process_prep_sub_arg_cloud($root);
}

#------------------------------------------------------------------------------
# Detects auxiliary particles using Interset features.
#------------------------------------------------------------------------------
sub is_auxiliary_particle
{
    my $self = shift;
    my $node = shift;
    return $node->match_iset( 'pos' => 'part', 'verbtype' => 'aux' );
}

#------------------------------------------------------------------------------
# Finds the leftmost verbal child if any. Useful to find the verbs belonging to
# auxiliary particles. (There may be other children having the 'comp' deprel;
# these children are complements to the particle-verb pair.)
#------------------------------------------------------------------------------
sub get_leftmost_verbal_child {
    my ($self, $node) = @_;
    return first {$_->match_iset(pos=>'verb', verbtype=>'!aux') && $_->conll_deprel eq 'comp'} $node->get_children({ordered=>1});
}

#------------------------------------------------------------------------------
# There are two auxiliary particles in BulTreeBank:
# 'да' is an infinitival* marker;
# 'ще' is used to construct the future tense.
# Both originally govern an infinitive verb clause.
# Both will be treated as subordinating conjunctions in Czech.
# *) Modern Bulgarian has no infinitive, да+[conjugated verb in present tense] is used instead.
#   There are also constructions, in which the following verb form is in past tense, then it can be considered
#   as an optative, since it expresses some wishes. For example, 'Да бях по-млад' -> 'If I was younger... [but I am not]'.
#   Also, in some cases да can also be a subordinator: Чакам да дойдеш -> 'I wait [wanting] you to come / čekám abys přišel.
#   Then we might say it is subjunctive.
# Passive constructions such as "тя(parent=да) трябва да(parent=трябва) е(parent=да) изписана(parent=да)"
# should be transformed to "тя(parent=изписана) трябва да(parent=трябва,afun=AuxC) е(parent=изписана,afun=AuxV) изписана(parent=да)"
# See https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s03.html#prstapas_rozliseni_stavu_a_pasiva_
#------------------------------------------------------------------------------
sub process_auxiliary_particles {
    my ($self, $root) = @_;
    foreach my $node ($root->get_descendants()) {
        next if !$self->is_auxiliary_particle($node);

        # Consider the first verbal child of the particle the clausal head.
        my $head = $self->get_leftmost_verbal_child($node);
        next if !$head;

        my @children = $node->children();

        # Reattach all other children to the new head.
        # Mark auxiliary "е" in passive constructions as AuxV
        foreach my $child (@children) {
            if ( $child != $head ) {
                $child->set_parent($head);
                if ($child->iset->verbtype eq 'aux'){
                    $child->set_afun('AuxV');
                }
            }
        }

        # Experiment: different treatment of 'da' and 'šte'.
        if ( $node->form() eq 'да' ) {

            # Treat the particle as a subordinating conjunction.
            $node->set_afun('AuxC');
            # "да" needs to be marked as an infinitive in order to collapse modal+да constructions
            # (да is a kind of infinitive particle, but the verb it precedes is fully conjugated).
            # We cannot do this inside Interset driver because tag "Tx" can be also "ще",
            # which should not be marked as an infinitive.
            $node->iset->set_verbform('inf');
        } else {   # ще
            $self->lift_node( $head, 'AuxV' );
        }
    }
    return;
}


#------------------------------------------------------------------------------
# Modal verbs are not marked in BulTreeBank, so we need to detect them based on lemmas.
#------------------------------------------------------------------------------
sub is_modal {
    my ($self, $node) = @_;
    # TODO: add the rest of BG modals
    return 1 if $node->lemma =~ /^(трябва|мога)(\_.*)?$/;
	return 0;
}

#------------------------------------------------------------------------------
# Constructions like "mogăl bi" (cs:mohl by). "mogăl" is a participle (in this
# case modal but it does not matter). "bi" is a form of the auxiliary verb
# "to be". In BulTreeBank, "bi" governs "mogăl". In PDT it would be vice versa.
#------------------------------------------------------------------------------
sub process_auxiliary_verbs
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    my @liftnodes;

    # Search for nodes to lift.
    foreach my $node (@nodes)
    {

        if ($self->is_modal($node)){
            $node->iset->set_verbtype('mod');
        }

        # Is this a non-auxiliary verb?
        # Is its parent an auxiliary verb?
        if (
            $node->match_iset( 'pos' => 'verb', 'verbtype' => '!aux', 'verbform' => 'part' )

            # &&
            # $node->form() eq 'могъл'
            )
        {
            my $parent = $node->parent();
            if (!$parent->is_root()
                &&

                # $parent->get_attr('conll_pos') eq 'Vxi'
                # $parent->match_iset('pos' => 'verb', 'verbtype' => 'aux', 'person' => 3, 'number' => 'sing')
                $parent->form() =~ m/^(би(ха)?|бях)$/
                )
            {
                push( @liftnodes, $node );
            }
        }
    }

    # Lift the identified nodes.
    foreach my $node (@liftnodes)
    {
        $self->lift_node( $node, 'AuxV' );
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the Bulgarian
# treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_stanford($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return non-head conjuncts, private modifiers of the head conjunct and all shared modifiers for the Stanford family of styles.
    # (Do not return delimiters, i.e. do not return all original children of the node. One of the delimiters will become the new head and then recursion would fall into an endless loop.)
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = grep {$_ != $node} ($coordination->get_conjuncts());
    push(@recurse, $coordination->get_shared_modifiers());
    push(@recurse, $coordination->get_private_modifiers($node));
    return @recurse;
}

#------------------------------------------------------------------------------
# Conjunction as the first word of the sentence is attached as 'conj' to the main verb in BulTreeBank.
# In PDT, it is the root of the sentence, marked as coordination, whose only member is the main verb.
#------------------------------------------------------------------------------
sub mark_deficient_clausal_coordination
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants( { ordered => 1 } );
    if ( $nodes[0]->conll_deprel() eq 'conj' )
    {
        my $parent = $nodes[0]->parent();
        if ( $parent->conll_deprel() eq 'ROOT' )
        {
            my $grandparent = $parent->parent();
            $nodes[0]->set_afun('Coord');
            $nodes[0]->set_parent($grandparent);
            $parent->set_parent( $nodes[0] );
            $parent->set_is_member(1);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::BG::Harmonize

Converts trees coming from BulTreeBank via the CoNLL-X format to the style of
the HamleDT (Prague). Converts tags and restructures the tree.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
