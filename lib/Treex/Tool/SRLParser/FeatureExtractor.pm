package Treex::Tool::SRLParser::FeatureExtractor;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/ uniq /;

has 'feature_delim' => (
    is      => 'rw',
    isa     => 'Str',
    default => ' ',
);

has 'value_delim' => (
    is      => 'rw',
    isa     => 'Str',
    default => '/',
);

has 'debug_printing_mode' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'empty_sign' => (
    is      => 'rw',
    isa     => 'Str',
    default => '_',
);

has '_feature_to_code' => (
    is          => 'ro',
    isa         => 'HashRef',
    default     => sub { {  'ChildrenPOS'       => 'P1',
                            'PredicateChildrenPOS'  => 'P1a',
                            'DepwordChildrenPOS'    => 'P1b',
                            'ChildrenPOSNoDup'  => 'P2',
                            'PredicateChildrenPOSNoDup' => 'P2a',
                            'DepwordChildrenPOSNoDup' => 'P2b',
                            'ConstituentPOSPattern' => 'P3',
                            'ConstituentPOSPattern+DepRelation' => 'P4',
                            'ConstituentPOSPattern+DepwordLemma' => 'P5',
                            'ConstituentPOSPattern+HeadwordLemma' => 'P6',
                            'DepRelation' => 'P7',
                            'DepRelation+DepwordLemma' => 'P8',
                            'DepRelation+HeadwordLemma' => 'P9',
                            'DepRelation+HeadwordLemma+DepwordLemma' => 'P10',
                            'Depword' => 'P11',
                            'DepwordLemma' => 'P12',
                            'DepwordLemma+RelationPath' => 'P13',
                            'DepwordPOS' => 'P13',
                            'DepwordPOS+HeadwordPOS' => 'P14',
                            'DownPathLength' => 'P15',
                            'FirstLemma' => 'P16',
                            'FirstPOS' => 'P17',
                            'FirstPOS+DepwordPOS' => 'P18',
                            'HeadwordLemma' => 'P19',
                            'HeadwordLemma+RelationPath' => 'P20',
                            'HeadwordPOS' => 'P21',
                            'LastLemma' => 'P22',
                            'LastPOS' => 'P23',
                            'Path' => 'P24',
                            'Path+RelationPath' => 'P25',
                            'PathLength' => 'P26',
                            'PFEATSplit' => 'P27',
                            'PredicatePFEATSplit' => 'P27a',
                            'DepwordPFEATSplit' => 'P27b',
                            'PositionWithPredicate' => 'P28',
                            'Predicate' => 'P29',
                            'Predicate+PredicateFamilyship' => 'P30',
                            'PredicateLemma' => 'P31',
                            'PredicateLemma+PredicateFamilyship' => 'P32',
                            'PredicateSense' => 'P33',
                            'PredicateSense+DepRelation' => 'P34',
                            'PredicateSense+DepwordLemma' => 'P35',
                            'PredicateSense+DepwordPOS' => 'P36',
                            'RelationPath' => 'P37',
                            'SiblingsRELNoDup' => 'P38',
                            'UpPath' => 'P39',
                            'UpPathLength' => 'P40',
                            'UpRelationPath+HeadwordLemma' => 'P41',
                            'PredicatePOS' => 'P42',
                            'DepwordFeat' => 'P43',
                            'PredicateFeat' => 'P44',
                            'Distance' => 'P45',
                            'PositionToPredicate' => 'P46',
                            'PredicatePosition' => 'P47',
                            'DepwordPosition' => 'P48',
                            'PredicateHeadword' => 'P49',
                            'PredicateHeadword' => 'P50',
                            'PredicateHeadwordPOS' => 'P51',
                            'PredicateHeadwordLemma' => 'P52',
                            'DepwordConstituentFirstWord' => 'P53',
                            'DepwordConstituentFirstPOS' => 'P54',
                            'DepwordConstituentFirstLemma' => 'P55',
                            'DepwordConstituentLastWord' => 'P56',
                            'DepwordConstituentLastPOS' => 'P57',
                            'DepwordConstituentLastLemma' => 'P58',
                            'IsInFrame' => 'P59',
                            'Frame' => 'P60',
                        } },
);

sub extract_features() {
    my ( $self, $a_root, $predicate, $depword ) = @_; 

    # Preprocessing: find out some information about predicate and depword candidates
    # to use in classification features 
    my $deprel = $depword->get_parent->id eq $predicate->id ? $depword->afun : $self->empty_sign;
    my @predicate_children_pos = map { substr($_->tag, 0, 1) } $predicate->get_children( { ordered => 1, add_self => 0 } );
    my @depword_children_pos = map { substr($_->tag, 0, 1) } $predicate->get_children( { ordered => 1, add_self => 0 } );
    my @path = $self->_find_path($a_root, $predicate, $depword);
    my $path_length = @path;
    my @pos_path = map { $_->tag ? substr($_->tag, 0, 1) : $self->empty_sign } @path;
    my @rel_path = map { $_->afun } @path;
    my $distance = abs($predicate->ord - $depword->ord);
    my $ord_diff = $predicate->ord - $depword->ord;
 
    my @features;

    ### Features from Che & spol. ###
    # For explanation of these feature names, see paper
    # "A Cascaded Syntactic and Semantic Dependency Parsing System":
    # http://ir.hit.edu.cn/~car/papers/conll08.pdf

    # ChildrenPOS
    push @features, $self->_make_feature('PredicateChildrenPOS', @predicate_children_pos);
    push @features, $self->_make_feature('DepwordChildrenPOS', @depword_children_pos);
    # ChildrenPOSNoDup
    push @features, $self->_make_feature('PredicateChildrenPOSNoDup', uniq @predicate_children_pos);
    push @features, $self->_make_feature('DepwordChildrenPOSNoDup', uniq @depword_children_pos);
    # ConstituentPOSPattern
    # ConstituentPOSPattern+DepRelation
    # ConstituentPOSPattern+DepwordLemma
    # ConstituentPOSPattern+HeadwordLemma
    # DepRelation
    push @features, $self->_make_feature('DepRelation', $deprel);
    # DepRelation+DepwordLemma
    push @features, $self->_make_feature('DepRelation+DepwordLemma', ( $deprel, $depword->lemma )); 
    # DepRelation+HeadwordLemma
    # DepRelation+HeadwordLemma+DepwordLemma
    # Depword
    push @features, $self->_make_feature('Depword', $depword->form);
    # DepwordLemma
    push @features, $self->_make_feature('DepwordLemma', $depword->lemma);
    # DepwordLemma+RelationPath
    push @features, $self->_make_feature('DepwordLemma+RelationPath', ($depword->lemma, @rel_path));
    # DepwordPOS
    push @features, $self->_make_feature('DepwordPOS', substr($depword->tag, 0, 1));
    # DepwordPOS+HeadwordPOS
    # DownPathLength
    # FirstLemma
    # FirstPOS
    # FirstPOS+DepwordPOS
    # HeadwordLemma
    # HeadwordLemma+RelationPath
    # HeadwordPOS
    # LastLemma
    # LastPOS
    # Path
    push @features, $self->_make_feature('Path', @pos_path);
    # Path+RelationPath
    push @features, $self->_make_feature('Path+RelationPath', (@pos_path, @rel_path));
    # PathLength
    push @features, $self->_make_feature('PathLength', $path_length);
    # PFEATSplit
    # PositionWithPredicate
    # Predicate
    push @features, $self->_make_feature('Predicate', $predicate->form);
    # Predicate+PredicateFamilyship
    # PredicateLemma
    push @features, $self->_make_feature('PredicateLemma', $predicate->lemma);
    # PredicateLemma+PredicateFamilyship
    # PredicateSense
    # PredicateSense+DepRelation
    # PredicateSense+DepwordLemma
    # PredicateSense+DepwordPOS
    # RelationPath
    push @features, $self->_make_feature('RelationPath', @rel_path);
    # SiblingsRELNoDup
    # UpPath
    # UpPathLength
    # UpRelationPath+HeadwordLemma
    
    ### My features ###

    # PredicatePOS
    push @features, $self->_make_feature('PredicatePOS', substr($predicate->tag, 0, 1));
    # DepwordFeat
    push @features, $self->_make_feature('DepwordFeat', $depword->tag);
    # PredicateFeat
    push @features, $self->_make_feature('PredicateFeat', $predicate->tag);
    # Distance
    push @features, $self->_make_feature('Distance', $distance);
    # PositionToPredicate
    push @features, $self->_make_feature('PositionToPredicate', ($ord_diff == 0 ? "IsPredicate" : ($ord_diff > 0 ? "BeforePredicate" : "AfterPredicate")));  
    # PredicatePosition
    push @features, $self->_make_feature('PredicatePosition', $predicate->ord);
    # DepwordPosition
    push @features, $self->_make_feature('DepwordPosition', $depword->ord);
    # PredicateHeadword
    # PredicateHeadword
    # PredicateHeadwordPOS
    # PredicateHeadwordLemma
    # DepwordConstituentFirstWord
    # DepwordConstituentFirstPOS
    # DepwordConstituentFirstLemma
    # DepwordConstituentLastWord
    # DepwordConstituentLastPOS
    # DepwordConstituentLastLemma
    # IsInFrame
    # Frame
   
    return join($self->feature_delim, @features);
}

sub _make_feature() {
    my ( $self, $name, @values ) = @_;

    return $self->_feature_to_code->{$name} . $self->value_delim . (@values ? join($self->value_delim, @values) : $self->empty_sign);
}

# Find path from start a-node to end a-node 
# and return an array of a-nodes along the path.
# The algorithm depends on each a-node having at most one parent
# and the a-tree having no loops.
sub _find_path() {
    my ( $self, $a_root, $start, $end ) = @_;
   
    return ($start) if ($start->id eq $end->id);

    # go up from a-node "start" to "a_root" and mark visited a-nodes
    my %start_up_path_nodes;
    my @start_up_path = ();
    
    my $act = $start;
    $start_up_path_nodes{$act->id} = 1;
    push @start_up_path, $act;
    
    while ($act->id ne $a_root->id) {
        $act = $act->parent;
        $start_up_path_nodes{$act->id} = 1;
        push @start_up_path, $act;
    }

    # go up from a-node end until marked a-node is reached
    my @end_up_path = ();
    $act = $end;
    while (not exists $start_up_path_nodes{$act->id}) {
        push @end_up_path, $act;
        $act = $act->parent;
    }

    # delete all a-nodes from common parent to a-root
    my $common_parent = $act;
    while ((pop @start_up_path)->id ne $common_parent->id) {
    }

    # concatenate paths
    my @path = (@start_up_path, $common_parent, reverse(@end_up_path)); 
    return @path;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::SRLParser::FeatureExtractor

=head1 SYNOPSIS

my $feature_extractor = Treex::Tool::SRLParser::FeatureExtractor->new();
    
my @a_nodes = $a_root->get_descendants;
        
foreach my $predicate_candidate (@a_nodes) {

    foreach my $depword_candidate (@a_nodes) {

        print $feature_extractor->extract_features($predicate_candidate, $depword_candidate);
          
    }

}   

=head1 DESCRIPTION

Feature extractor for SRL parser according to L<Che et al. 2009|http://ir.hit.edu.cn/~car/papers/conll09.pdf>. Given a pair of two treex a-nodes, it returns a string of classification features.

=head1 PARAMETERS

=over

=item feature_delim

Delimiter between features. Default is space, because Maximum Entropy Toolkit
expects spaces between features. 

=item value_delim

Delimiter between feature values in combined features, such as
PredicatePOS+DepwordPOS. This only makes sense in debug printing mode to make
combined features readable.

=item debug_printing_mode

If true, classification feature string is printed in human readable format.
Currently, all outputs are in debug printing mode, feature encoding to ensure
smaller memory and disk usage need to be implemented.

=item empty_sign

A string for denoting empty or undefined values, such as no semantic relation
in t-tree, no syntactic relation in a-tree, empty values for features, etc.

=back

=head1 METHODS 

=over

=item $self->extract_features( $self, $predicate, $depword )

Given two treex a-nodes, a predicate candidate and a depword candidate, it
returns a string of classification features.

=back

=head1 TODO

Implement all classification features as suggested by the paper.
Currently, all outputs are in debug printing mode, feature encoding to ensure
smaller memory and disk usage needs to be implemented.

=head1 AUTHOR

Jana Straková <strakova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
