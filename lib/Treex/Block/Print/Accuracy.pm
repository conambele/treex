package Treex::Block::Print::Accuracy;
use Moose;

use Treex::Core::Common;
use Treex::Block::Print::AttributeArrays;

extends 'Treex::Core::Block';
with 'Treex::Block::Print::Overall';

has '+language' => ( required => 1 );

has 'reference_selector' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'ref',
);

has 'print_limit' => (
    is      => 'ro',
    isa     => 'Int',
    default => 10,
);

has 'layer' => (
    isa => enum( [ 'a', 't', 'p', 'n' ] ),
    is => 'ro',
    required => 1
);

has 'attributes' => (
    isa      => 'Str',
    is       => 'ro',
    required => 1
);

has '_attr_arrays' => ( isa => 'Object', is => 'rw', lazy_build => 1 );

# Total number of all tested values
has '_total' => ( isa => 'Int', is => 'rw', default => 0 );

# Number of correct values
has '_good' => ( isa => 'Int', is => 'rw', default => 0 );

# List of the most common errors
has '_errors' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );

sub _build__attr_arrays {

    my ($self) = @_;

    return Treex::Block::Print::AttributeArrays->new( { layer => $self->layer, attributes => $self->attributes } );
}

sub process_bundle {

    my ( $self, $bundle ) = @_;
    my $tst = $bundle->get_zone( $self->language, $self->selector );
    my $ref = $bundle->get_zone( $self->language, $self->reference_selector );   

    log_fatal('Zone does not exist!') if ( !$tst || !$ref );

    my @tst_vals = @{ $self->_attr_arrays->process_zone($tst) };
    my @ref_vals = @{ $self->_attr_arrays->process_zone($ref) };

    log_fatal('Not the same number of elements for golden and testing data, cannot measure accuracy!') if ( @tst_vals != @ref_vals );

    # Count the total number of nodes and the number of nodes with the correct value of the specified attribute(s)
    $self->_set_total( $self->_total + @tst_vals );

    my $good = 0;
    my $errors = $self->_errors;
    for ( my $i = 0; $i < @tst_vals; ++$i ) {
        if ( $tst_vals[$i] eq $ref_vals[$i] ){
            $good++;
        }
        else {
            my $mid = $tst_vals[$i] . "\t" . $ref_vals[$i];
            $errors->{$mid} = $errors->{$mid} ? $errors->{$mid} + 1 : 1;
        }
    }

    $self->_set_good( $self->_good + $good );

    return;
}

sub _reset_stats {

    my ($self) = @_;

    $self->_set_total(0);
    $self->_set_good(0);
    $self->_set_errors( {} );
}

sub _print_stats {

    my ($self) = @_;
    my $accuracy = sprintf( "%.5f", $self->_good / $self->_total );

    print "Accuracy for " . $self->attributes . " = " . $accuracy . "\n";
    print "\tTotal: " . $self->_total . ", Good: " . $self->_good . "\n";
    print "Most common errors:\n";
    printf "%-35s %-35s %6s\n", 'TST', 'REF', 'COUNT';
    
    my @sorted_errs = sort { $self->_errors->{$b} <=> $self->_errors->{$a} } keys %{ $self->_errors };
    if ( $self->print_limit < @sorted_errs ){
        @sorted_errs = @sorted_errs[ 0 .. $self->print_limit - 1 ];
    }
        
    foreach my $err (@sorted_errs){
        my ($tst, $ref) = split /\t/, $err;
        printf "%-35.35s %-35.35s %6d\n", $tst, $ref, $self->_errors->{$err};
    }
    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::Accuracy

=head1 DESCRIPTION

Prints the accuracy statistics (i.e. correct / all values) and a list of most common errors for the given
layer and attributes.

The typical usage includes measuring tagging and parsing accuracy (using the a-layer along with the C<tag, lemma>
and C<afun, parent-&gt;ord> C<attributes> setting, respectively). 

The number of nodes in the reference and testing trees must always be exactly the same.

=head1 ATTRIBUTES

=over

=item C<layer>

The layer at which this block should be applied, e.g. C<t> or C<a>.

=item C<attributes>

The attributes to be measured (e.g. C<"tag lemma"> on the a-layer will measure tagging and lemmatizing accuracy).

The list of attributes should be separated with commas or spaces. The L<Treex::Block::Write::LayerAttributes> role
is used to gather the attribute values.

=item C<reference_selector>

The selector for the reference translation. Defaults to C<ref>.

=item C<print_limit>

How many of the most common errors should be printed (default: 10).

=item C<overall>

If this is set to 1, an overall score for all the processed documents is printed instead of a score for each single
document.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
