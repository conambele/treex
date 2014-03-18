package Treex::Block::HamleDT::Transform::StanfordTypes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

# Prague afun to Stanford type
# TODO 'dep' means I don't know what to use,
# usually it should eventually become something more specific!
my %afun2type = (

    # ordinary afuns
    Sb   => \&{Sb},
    Obj  => \&{Obj},
    Pnom => \&{PnomAtv},
    AuxV => \&{AuxV},
    Pred => 'root',
    AuxP => \&{AuxP},
    Atr  => \&{Atr},
    Adv  => \&{Adv},
    Coord => 'cc',

    # less ordinary afuns
    NR         => 'dep',
    AuxA       => 'det',      # not always used in the harmonization!
    Neg        => 'neg',      # not always used in the harmonization!
    ExD        => 'remnant',
    Apos       => 'appos',    # ?
    Apposition => 'appos',    # ???
    Atv        => \&{PnomAtv},
    AtvV       => \&{PnomAtv},
    AtrAtr     => \&{Atr},
    AtrAdv     => \&{Atr},
    AdvAtr     => \&{Atr},
    AtrObj     => \&{Atr},
    ObjAtr     => \&{Atr},
    PredC      => 'dep',      # only in ar; "conjunction as the clause's head"
    PredE      => 'dep',      # only in ar; "existential predicate"
    PredP      => 'dep',      # only in ar; "adposition as the clause's head"
    Ante       => 'dep',      # only in ar;

    # some crazy Aux*
    AuxC => 'mark',
    AuxG => 'dep', # usually already marked as 'punct' from MarkPunct
    AuxK => 'dep', # usually already marked as 'punct' from MarkPunct
    AuxX => 'dep', # usually already marked as 'punct' from MarkPunct
    AuxT => \&{Adv},
    AuxR => \&{Adv},
    AuxO => \&{Adv},
    AuxE => 'dep',   # only in ar(?)
    AuxM => 'dep',   # only in ar(?)
    AuxY => \&{AuxY},
    AuxZ => \&{Adv}, # it seems to be labeled e.g. as advmod by the Stanford parser
);

sub process_anode {
    my ( $self, $anode ) = @_;

    if ( defined $anode->conll_deprel && $anode->conll_deprel ne '' ) {
        # type already set by preceding blocks -> skip
        return;
    }

    my $form = $anode->form;

    
    # CONVERSION ACCORDING TO %afun2type

    # get the type;
    # either already the type string
    # or a reference to a subroutine that will return the type string
    my $type = $afun2type{$anode->afun};
    if ( defined $type ) {
        if ( ref($type) ) {
            # asserf ref($type) == 'CODE'
            $type = &$type($self, $anode);
        }
        # else $type is already the type string
    }
    else {
        log_warn "Unknown type for afun " . $anode->afun . " ($form)!";
        $type = 'dep';
    }
    
    
    # SOME POST-CHECKS

    # root
    if ( $anode->get_parent()->is_root()) {
        $type = 'root';
    }
    # negations
    elsif ( $anode->match_iset( 'pos' => '~part', negativeness => 'neg' ) ) {
        $type = 'neg';
    }
    # determiners
    elsif ( $anode->match_iset( 'subpos' => '~art|det' ) ) {
        $type = 'det';
    }

    # adpositions (some adpositions are AuxC and should stay mark)
    elsif ( $anode->match_iset( 'pos' => '~prep' ) &&
        $type ne 'mark'
    ) {
       $type = $self->AuxP($anode); 
    }

    # MARK CONJUNCTS
    # the first conjunct (which is the head of the coordination) is NOT marked
    # by is_member, so only its children get the 'conj' type, which is correct
    # (relies on the current behaviour of Transform::CoordStyle
    if ( $anode->is_member ) {
        $type = 'conj';
    }

    # SET THE RESULTING SD TYPE
    $anode->set_conll_deprel($type);

    return;
}

# AFUN-SPECIFIC SUBS

# hopefully OK
sub Sb {
    my ( $self, $anode ) = @_;

    my $type = 'subj';

    if ( $anode->match_iset( 'pos' => '~noun' ) ) {
        $type = 'nsubj';
        if ( $self->parent_is_passive_verb($anode)) {
            $type = 'nsubjpass';
        }
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) ) {
        $type = 'csubj';
        if ( $self->parent_is_passive_verb($anode)) {
            $type = 'csubjpass';
        }
    }

    return $type;
}

# hopefully OK
sub Obj {
    my ( $self, $anode ) = @_;

    my $type = 'comp';

    if ( $anode->match_iset( 'pos' => '~noun' ) ) {
        $type = 'obj';
        # elsif ( $anode->match_iset( case => '~acc' ) ) {
        #   $type = 'dobj';
        # }
        # elsif ( $anode->match_iset( case => '~dat' ) ) {
        #   $type = 'iobj';
        # }
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) ) {
        if ( $self->get_simplified_verbform($anode) eq 'fin' ) {
            $type = 'ccomp';
        }
        else {
            $type = 'xcomp';
        }
    }

    return $type;
}

# Pnom or Atv (Pnom will hopefully get a different label in the subsequent
# StanfordCopulas block)
sub PnomAtv {
    my ( $self, $anode ) = @_;

    my $type = 'comp';

    if ( $anode->match_iset( 'pos' => '~adj|verb' ) ) {
        $type = 'xcomp';
    }
    elsif ( $anode->match_iset( 'pos' => '~noun') ) {
        $type = 'obj';
    }

    return $type;
}

# hopefully OK
sub AuxV {
    my ( $self, $anode ) = @_;

    my $type = 'aux';

    if ( $self->parent_is_passive_verb($anode) ) {
        $type = 'auxpass';
    }

    return $type;
}

sub AuxP {
    my ($self, $anode) = @_;

    my $type = 'case';

    # compound preps
    my $parent = $anode->get_parent();
    if ( defined $parent &&
        ($parent->match_iset('pos', '~prep') || $parent->afun eq 'AuxP')
    ) {
        # compound preps: the "auxiliaries" are thought to be parts of a
        # multi word expression
        $type = 'mwe';
    }

    return $type;
}

# TODO
sub Atr {
    my ( $self, $anode ) = @_;

    my $type = 'mod';

    # TODO: I usually do not know the priorities,
    # therefore I use "if" instead of "elsif"
    # and I do not nest the ifs
    
    # noun modifiers
    if ( $self->parent_has_pos($anode, 'noun') ) {
        if ( $anode->match_iset( 'pos' => '~noun' ) ) {
            $type = 'nmod';
        }
        elsif ( $anode->match_iset( 'pos' => '~adj' ) ) {
            $type = 'amod';
        }
        elsif ( $anode->match_iset( 'pos' => '~adv' ) ) {
            $type = 'advmod';
        }
        elsif ( $anode->match_iset( 'pos' => '~verb' ) ) {
            if ( $self->get_simplified_verbform($anode) eq 'fin' ) {
                $type = 'rcmod';
            }
            else {
                $type = 'vmod';
            }
        }

    }
    # verb modifiers
    elsif ( $self->parent_has_pos($anode, 'adj') ) {
        if ( $anode->match_iset( 'pos' => '~adj' ) ) {
            $type = 'xcomp';
        }
    }
    # verb modifiers
    elsif ( $self->parent_has_pos($anode, 'verb') ) {
        if ( $anode->match_iset( 'pos' => '~adj' ) ) {
            $type = 'xcomp';
        }
    }

    # possessives
    #if ( $anode->match_iset( 'poss' => '~poss' ) ) {
    #    $type = 'poss';
    #}
    # numerals
    if ( $anode->match_iset( 'pos' => '~num' ) ) {
        if ( $self->parent_has_pos($anode, 'num') ) {
            $type = 'compmod';
        } else {
            $type = 'nummod';
        }
    }
    # advmod
    if ( $anode->match_iset( 'pos' => '~adv' ) ) {
        $type = 'advmod';
    }

    return $type;
}

# TODO
sub Adv {
    my ( $self, $anode ) = @_;

    my $type = 'mod';

    if ( $anode->match_iset( 'pos' => '~adv' ) ) {
        $type = 'advmod';
    }
    elsif ( $anode->match_iset( 'pos' => '~noun' ) ) {
        $type = 'npadvmod';
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) &&
        $self->parent_has_pos($anode, 'verb')
    ) {
        $type = 'advcl';
    }
    elsif ( $anode->match_iset( 'pos' => '~adj' ) ) {
        if ( $self->parent_has_pos($anode, 'noun') ) {
            $type = 'amod';
        }
        elsif ( $self->parent_has_pos($anode, 'verb') ) {
            $type = 'xcomp';
        }
    }

    return $type;
}

sub AuxY {
    my ($self, $anode) = @_;

    my $type;
    
    my $parent = $anode->get_parent();
    if ( defined $parent && $parent->afun =~ /^Aux[XY]$/) {
        # compound AuxY
        $type = 'mwe';
    } else {
        # it seems to be labeled e.g. as advmod by the Stanford parser
        $type = $self->Adv($anode);
    }
    
    return $type;
}

# HELPER SUBS
# I use get_parent() and thanks to the properties of Stanford Dependencies, this
# is the same as using get_eparent() for the first conjunct, and irrelevant for
# other conjuncts since they all should get the 'conj' type

my %simplified_verbform = (
    '' => 'fin',
    fin => 'fin',
    inf => 'inf',
    sup => 'inf',
    part => 'inf',
    trans => 'inf',
    ger => 'inf',
);

sub get_simplified_verbform {
    my ($self, $anode) = @_;

    my $verbform = $anode->get_iset('verbform');
    # TODO (now takes the first one from multiple values)
    $verbform =~ s/\|.*//;

    return $simplified_verbform{$verbform} // 'fin';
}

sub parent_is_passive_verb {
    my ($self, $anode) = @_;

    my $parent = $anode->get_parent();
    if ( defined $parent &&
        $parent->match_iset( 'pos' => '~verb', voice => '~pass' )
    ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub parent_has_pos {
    my ($self, $anode, $pos) = @_;

    my $parent = $anode->get_parent();
    if ( defined $parent &&
        $parent->match_iset( 'pos' => '~' . $pos )
    ) {
        return 1;
    }
    else {
        return 0;
    }
}


1;

=head1 NAME 

Treex::Block::HamleDT::Transform::StanfordTypes -- convert from HamleDT afuns to Stanford
dependencies types

=head1 DESCRIPTION

The Stanford dependency types are stored into C<conll/deprel>.
This is for this block to be able to look at the C<afun>s at any time;
however, this block should B<not> look at original deprels, as it should be
language-independent (and especially treebank-independent).

TODO: not yet ready, still many things to solve

Coordination structures should get marked correctly -- the block relies on
the data previously having been processed by L<HamleDT::Transform::CoordStyle>.

Punctuation is to have been marked by L<HamleDT::Transform::MarkPunct>.

If C<conll/deprel> already contains a value, this value is kept. Delete the
values first to avoid that. (But do that before calling
L<HamleDT::Transform::MarkPunct> since this block stores the C<punct> types into
C<conll/deprel>.)

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

