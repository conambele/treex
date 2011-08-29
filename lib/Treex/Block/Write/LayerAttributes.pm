package Treex::Block::Write::LayerAttributes;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Treex::Core::Log;
use Treex::PML::Instance;

requires '_process_tree';

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

# This is a parsed list of attributes, constructed from the attributes parameter.
has '_attrib_list' => (
    isa        => 'ArrayRef',
    is         => 'ro',
    builder    => '_build_attrib_list',
    lazy_build => 1
);

# A list of output attributes, given all the modifiers applied
has '_output_attrib' => (
    isa    => 'ArrayRef',
    is     => 'ro',
    writer => '_set_output_attrib',
);

has '_modifiers' => (
    isa    => 'HashRef',
    is     => 'ro',
    writer => '_set_modifiers',
);

# Parse the attribute list given in parameters.
sub _build_attrib_list {

    my ($self) = @_;
    return _split_csv_with_brackets( $self->attributes );
}

# Build the output attributes
sub BUILD {

    my ( $self, $args ) = @_;
    my @output_attr = ();
    my %modifiers   = ();

    foreach my $attr ( @{ $self->_attrib_list } ) {
        if ( my ( $pckg, $func_args ) = _get_function_pckg_args($attr) ) {

            # find the package and check the role
            eval "require $pckg" || log_fatal('Cannot require package ' . $pckg);
            {
                no strict 'refs';
                $modifiers{$pckg} = $pckg->new();
            }
            log_fatal("The $pckg package doesn't have the Treex::Block::Write::LayerAttributes::AttributeModifier role!")
                if ( !$modifiers{$pckg}->does('Treex::Block::Write::LayerAttributes::AttributeModifier') );

            # get all return values
            push @output_attr, map { $attr . $_ } @{ $modifiers{$pckg}->return_values_names };
        }
        else {
            push @output_attr, $attr;
        }
    }

    $self->_set_output_attrib( \@output_attr );
    $self->_set_modifiers( \%modifiers );
   
    return;
}

# Split space-or-comma separated values that may contain brackets with enclosed commas or spaces
sub _split_csv_with_brackets {

    my ($str) = @_;
    $str .= ' ';
    my @arr = ();
    while ( $str =~ m/([a-zA-Z0-9_:-]+\([^\)]*\)+|[^\(\s,]*)[\s,]+/g ){
        push @arr, $1;
    }

    return \@arr;
}

sub process_zone {

    my $self = shift;
    my ($zone) = @_;    # pos_validated_list won't work here

    if ( !$zone->has_tree( $self->layer ) ) {
        log_fatal( 'No tree for ' . $self->layer . ' found.' );
    }
    my $tree = $zone->get_tree( $self->layer );

    $self->_process_tree($tree);
    return 1;
}

sub _get_function_pckg_args {

    my ($attrib) = @_;

    if ( my ( $func, $args ) = $attrib =~ m/^([A-Za-z_0-9:]+)\((.*)\)$/ ) {

        if ( $func !~ m/::./ ) {    # default package: Treex::Block::Write::LayerAttributes
            $func = 'Treex::Block::Write::LayerAttributes::' . $func;
        }
        return ( $func, $args );
    }
    return;
}

sub _get_modified {

    my ( $self, $node, $attrib, $alignment_hash ) = @_;

    if ( my ( $pckg, $args ) = _get_function_pckg_args($attrib) ) {

        # obtain all the arguments
        my @vals = ();
        foreach my $arg ( @{ _split_csv_with_brackets($args) } ) {
            my ( $curnames, $curvals ) = $self->_get_modified( $node, $arg, $alignment_hash );
            push @vals, @{$curvals};
        }

        # call the modifier function on them
        my $func = $pckg . '::modify';
        {
            no strict 'refs';
            @vals = ( &$func(@vals) );
        }

        # harvest the resutls
        return ( [ map { $attrib . $_ } @{ $self->_modifiers->{$pckg}->return_values_names } ], \@vals );
    }
    else {
        return ( [$attrib], [ $self->_get_data( $node, $attrib, $alignment_hash ) ] );
    }
}

# Return all the required information for a node as a hash
sub _get_info_hash {

    my ( $self, $node, $alignment_hash ) = @_;
    my %info;

    foreach my $attrib ( @{ $self->_attrib_list } ) {

        my ( $names, $vals ) = $self->_get_modified( $node, $attrib, $alignment_hash );
        foreach my $i ( 0 .. ( @{$names} - 1 ) ) {
            $info{ $names->[$i] } = $vals->[$i];
        }
    }
    return \%info;
}

sub _get_data {

    my ( $self, $node, $attrib, $alignment_hash ) = @_;

    my ( $ref, $ref_attr ) = split( /->/, $attrib, 2 );

    # references
    if ($ref_attr) {

        # gather referenced nodes
        my @nodes;

        # special references -- methods: syntactic relations
        if ( $ref eq 'parent' ) {
            @nodes = ( $node->get_parent() );
        }
        elsif ( $ref eq 'children' ) {
            @nodes = $node->get_children( { ordered => 1 } );
        }
        elsif ( $ref eq 'echildren' ) {
            @nodes = $node->get_echildren( { or_topological => 1, ordered => 1 } );
        }
        elsif ( $ref eq 'eparents' ) {
            @nodes = $node->get_eparents( { or_topological => 1, ordered => 1 } );
        }
        elsif ( $ref eq 'nearest_eparent' ) {
            @nodes = $node->get_eparents( { or_topological => 1, ordered => 1 } );
            if ( @nodes > 0 ) {
                my $nearest = $nodes[0];
                foreach my $eparent (@nodes) {
                    $nearest = $eparent if ( abs( $eparent->ord - $node->ord ) < abs( $nearest->ord - $node->ord ) );
                }
                @nodes = ($nearest);
            }
        }

        # alignment relation
        elsif ( $ref eq 'aligned' ) {

            # get alignment from the mapping provided in a hash
            if ($alignment_hash) {
                my $id = $node->id;
                if ( $alignment_hash->{$id} ) {
                    @nodes = @{ $alignment_hash->{$id} };
                }
            }

            # get alignment from $node->get_aligned_nodes()
            else {
                my ( $aligned_nodes, $aligned_nodes_types ) = $node->get_aligned_nodes();
                if ($aligned_nodes) {
                    @nodes = @{$aligned_nodes};
                }
            }
        }

        # referencing attributes
        else {

            # find references
            my @values = Treex::PML::Instance::get_all( $node, $ref );
            my $document = $node->get_document();
            @nodes = @values ? map { $document->get_node_by_id($_) } grep {$_} @values : ();

            # sort, if possible
            if ( @nodes > 0 and $nodes[0]->does('Treex::Core::Node::Ordered') ) {
                @nodes = sort { $a->ord <=> $b->ord } @nodes;
            }
        }

        # call myself recursively on the referenced nodes
        return join( ' ', grep { defined($_) } map { $self->_get_data( $_, $ref_attr, $alignment_hash ) } @nodes );
    }

    # plain attributes
    else {

        # special attribute -- address (calling get_address() )
        if ( $attrib eq 'address' ) {
            return $node->get_address();
        }

        # plain attributes
        else {
            my @values = Treex::PML::Instance::get_all( $node, $attrib );

            return if ( @values == 1 and not defined( $values[0] ) );    # leave single undefined values as undefined
            return join( ' ', grep { defined($_) } @values );
        }

    }
}

# Return all the required information for a node as an array
sub _get_info_list {

    my ( $self, $node, $alignment_hash ) = @_;

    my $info = $self->_get_info_hash( $node, $alignment_hash );
    return [ map { $info->{$_} } @{ $self->_output_attrib } ];
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes

=head1 DESCRIPTION

A Moose role for Write blocks that may be configured to use different layers and different attributes. All blocks with this
role must override the C<_process_tree()> method.

An arbitrary number of attribute references may be dereferenced using a C<-&gt;> character sequence, e.g. 
C<a/aux.rf-&gt;parent-&gt;tag>. Several special references — C<parent>, C<children>, C<eparents>, C<echildren> and C<aligned>
— are supported in addition to any referencing attribute values within the nodes themselves:

=over

=item C<aligned> means all nodes aligned to this node. 

If alignment info is not stored
in nodes of this tree but in their counterparts, you must provide a backward
node id to aligned nodes mapping (Str to ArrayRef[Node]) as a hash reference,
called C<$alignment_hash> in the code. For an example on how to do that,
see L<Treex::Block::Write::AttributeSentencesAligned>.

=item C<eparents>, C<echildren> looks for all effective parents or children of the current node.

=item C<nearest_eparent> finds the (topologically) nearest effective parent of this node.

=back

All values of multiple-valued attributes are returned, separated with a space.

Furthermore, text modifying functions may be applied to the retrieved attribute values, e.g. 
C<CzechCoarseTag(a/aux.rf-&gt;tag)>. Such functions may take more arguments and return more values. Nesting
the modifiing functions is also allowed. 

The text modifying function must be a package that implements the L<Treex::Block::Write::LayerAttributes::AttributeModifier>
role. All packages in the L<Treex::Block::Write::LayerAttributes> directory role are supported implicitly, 
without the need for full package specification; packages in other locations need to have their full package
name included. 

=head1 PARAMETERS

=over

=item C<layer>

The annotation layer to be processed (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<attributes>

A space-or-comma-separated list of attributes (relating to the tree nodes on the specified layer) to be 
processed, including references and text modifications (see the general description for more information).
 
This parameter is required.

=back

=head1 TODO

=over 

=item * 

Make the separator for multiple-valued attributes configurable.

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
