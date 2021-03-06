package Treex::Block::A2A::EN::EnhanceInterset;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    # fix articles
    if ( $anode->lemma =~ /^(a|the)$/ and $anode->tag eq 'DT' ) {
        $anode->set_iset( 'prontype' => 'art' );
    }

    # fill in definiteness for articles
    if ( $anode->match_iset( 'prontype' => 'art' ) ) {
        if ( $anode->lemma eq 'the' ) {
            $anode->iset->set_definiteness('def');
        }
        elsif ( $anode->lemma =~ /^an?$/ ) {
            $anode->iset->set_definiteness('ind');
        }
    }

    # 'one' as a personal pronoun -- set person (3rd) and number (sg), do not set gender
    if ( $anode->lemma eq 'one' and $anode->tag eq 'PRP' ) {
        $anode->set_iset( 'person' => 3, 'number' => 'sing' );
    }
    
    # distinguish attributive vs. nominal usage of relative pronouns "which" and alike (needed for SetFormeme)
    if ( $anode->tag eq 'WDT' ){
        if ( $anode->afun =~ /^(Sb|Obj)$/ ){
            $anode->iset->set_synpos('subst');
        }
        elsif ( $anode->afun eq 'Atr' ){
            $anode->iset->set_synpos('attr');
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::EN::EnhanceInterset

=head1 DESCRIPTION

Enhance Interset values based on current Interset tags and lemmas.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
