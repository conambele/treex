package Treex::Block::A2W::PT::ConcatenateTokens;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root   = $zone->get_atree();
    my $sentence = join ' ',
        map { $_->form || '' }
        $a_root->get_descendants( { ordered => 1 } );

    # Portuguese contractions, e.g. "de_" + "o" = "do"
    $sentence =~ s/\bpor ([oa]s?)\b/pel$1/g; # pelo, pela, pelos, pelas
    $sentence =~ s/\ba a(s?)\b/à$1/g;    # à, às
    $sentence =~ s/\ba (os?) /a$1/g;   # ao, aos
    $sentence =~ s/\bem ([oa]s?|um|uma|uns|umas)\b/n$1/g;    # no, na, nos, nas, num, numa, nuns, numas
    $sentence =~ s/\bde ([oa]s?|um|uma|uns|umas|este|esta)\b/d$1/g;    # do, da, dos, das, dum, duma, duns, dumas, deste, desta,...

    # TODO: detached  clitic, e.g. "dá" + "-se-" + "-lhe" + "o" = "dá-se-lho"


    $sentence =~ s/ +/ /g;
    $sentence =~ s/ ([!,.?:;])/$1/g;
    $sentence =~ s/(["”’])\./\.$1/g;
    $sentence =~ s/ ([’”])/$1/g;
    $sentence =~ s/([‘“]) /$1/g;

    $sentence =~ s/ ?([\.,]) ?([’”"])/$1$2/g;    # spaces around punctuation

    $sentence =~ s/ -- / – /g;


    # (The whole sentence is in parenthesis).
    # (The whole sentence is in parenthesis.)
    if ( $sentence =~ /^\(/ ) {
        $sentence =~ s/\)\./.)/;
    }

    # HACKS:
    $sentence =~ s/muito muito/muito, muito/g;
    $sentence =~ s/``\s*/“/g;
    $sentence =~ s/\s*''/”/g;

    $zone->set_sentence($sentence);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::PT::ConcatenateTokens

=head1 DESCRIPTION

Creates a sentence as a concatenation of a-nodes, removing spacing where needed.

Handling Portuguese contractions (e.g. "de" + "o" = "do").

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
