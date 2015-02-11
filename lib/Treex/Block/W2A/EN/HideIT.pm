package Treex::Block::W2A::EN::HideIT;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ($self, $zone) = @_;
    my ($changed_sentence, $entities_ref) = substitute_entities($zone->sentence);
    #print STDERR "New snt: $changed_sentence\n";
    $zone->set_sentence($changed_sentence);
    $zone->get_bundle()->wild->{entities} = $entities_ref;
    print STDERR "Ents for $changed_sentence:\n", join (", ", @{$entities_ref->{'entities'}}), "\n";
    return;
}

sub substitute_entities {
  my $sentence = shift;
  my $new_sentence = $sentence;
  my @entities;
  my @commands;
  $sentence = lcfirst($sentence);
  $sentence =~ s/$/ /;
  $sentence =~ s/^/ /;
  #$sentence =~ s/(["<>{}“”«»–|—„‚‘]|\[|\]|``|\'\'|‘‘|\^)/ $1 /g;
  my $quotes = [
    {start => '"', end =>'"'}, 
    {start => "'", end =>"'"}, 
    {start => '“', end =>'”'}, 
    {start => '«', end =>'»'},
    {start => '„', end =>'“'},
    {start => '‚', end =>'‘'},    
    {start => '``', end =>'``'}
  ];
  print STDERR "Collecting cmds...\n";  
  foreach my $quote (@$quotes){
    my $start = $quote->{start};
    my $end = $quote->{end};
    while($sentence =~ s/($start[A-Za-z][^$end]+$end)/xxxCMDxxx/){
      push(@commands, $1);
      print STDERR "Cmd: $1\n";
    }  
  }
  $sentence =~ s/^\s+//;
  $sentence = ucfirst($sentence);
  return ($sentence, {entities=> \@entities, commands=> \@commands});
  
  print STDERR "Collecting entites...\n";
  while($sentence =~ s/(["<>{}“”«»–|—„‚‘\s]|\[|\]|``|\'\'|‘‘|\^)([A-Z][a-z]+)/$1xxxNExxx/){
    push(@entities, $2);
    print STDERR "Entity: $2\n";
  }  
}
1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::HideNE - hide some entites from tokenizer

=head1 DESCRIPTION

All hidden entites are stored in the bundle's wild attr. 


=head1 OVERRIDEN METHODS

=head2 from C<Treex::Core::Block>

=over 4

=item process_atree

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009 - 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
