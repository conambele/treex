package Treex::Block::Print::IntersetDriverStub;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has driver_name => ( is => 'ro', isa => 'Str', default => 'XY::TagSet', documentation => 'name of the driver, e.g. EN::CoNLL2007');
has examples => ( isa => 'Int', is => 'ro', default => 5, documentation => 'How many example values (forms, deprels and parent cpos) should be printed');

# TODO: parameters to opt for pos instead of cpos and lemma instead of form

my (%total, %pos_form, %pos_deprel, %pos_parent_pos);

sub process_anode {
    my ($self, $anode) = @_;
    my $pos = $anode->conll_cpos;
    my $parent = $anode->get_parent;
    $total{$pos}++;
    $pos_form{$pos}{$anode->form // '<NONE>'}++;
    $pos_deprel{$pos}{$anode->conll_deprel // '<NONE>'}++;
    $pos_parent_pos{$pos}{$parent->is_root ? '<ROOT>' : $parent->conll_cpos // '<NONE>'}++; #/
    return;
}

sub top_examples {
    my ($self, $h) = @_;
    my @keys = sort {$h->{$b} <=> $h->{$a}} keys %$h;
    my $examples = $self->examples - 1;
    $examples = $#keys if $examples > $#keys;
    return join ' ',  map {"$_=".$h->{$_}} @keys[0 .. $examples];
}


sub process_end {
    my ($self) = @_;
    my $driver_name = $self->driver_name;
    print <<"END";
package Treex::Tool::Interset::$driver_name;
use utf8;
use Moose;
with 'Treex::Tool::Interset::Driver';

# See https://wiki.ufal.ms.mff.cuni.cz/user:zeman:interset:features
my \$DECODING_TABLE = {
END

    for my $tag (sort {$total{$b} <=> $total{$a}} keys %total){
        printf "%20s => { pos => ''}, # $total{$tag}\n", $tag;
        print "# FORM: ". $self->top_examples($pos_form{$tag}). "\n";
        print "# DEPREL: ". $self->top_examples($pos_deprel{$tag}). "\n";
        print "# PARENT POS: ". $self->top_examples($pos_parent_pos{$tag}). "\n\n";
    }

    print <<"END";
};

sub decoding_table {
    return \$DECODING_TABLE;
}

1;

__END__

=head1 NAME

Treex::Tool::Interset::$driver_name

=head1 AUTHOR

Your Name <email>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
END

    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::IntersetDriverStub

=head1 SYNOPSIS

 treex Read::CoNLLX from=sample.conll Print::IntersetDriverStub driver_name=EN::CoNLL2007 > CoNLL2007.pm

=head1 DESCRIPTION

Prepare a stub of a Perl source code of an Interset driver
based on morphological tags (conll_cpos) occuring in a given Treex document.

=head1 PARAMETERS

=head2 driver_name

name of the driver, e.g. EN::CoNLL2007

=head2 examples

How many example values (forms, deprels and parent cpos) should be printed

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.