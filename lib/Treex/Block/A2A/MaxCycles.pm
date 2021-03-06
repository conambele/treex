package Treex::Block::A2A::MaxCycles;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'to_language' => ( is => 'rw', isa => 'Str', default => '' );
has 'to_selector' => ( is => 'rw', isa => 'Str', default => '' );

my $EDGE_PENALTY = 3;
my $ALIGNMENT_BONUS = 1;

sub copy_array {
    my ($array1, $array2) = @_;
    foreach my $i (0 .. $#$array1) {
        foreach my $j (0 .. $#{$$array1[$i]}) {
            $$array2[$i][$j] = $$array1[$i][$j];
        }
    }
}

sub find_best_paths {
    my ($scores, $paths, $max_length) = @_;
    my $size = $#$scores;
    foreach my $i (0 .. $size) {
        foreach my $j (0 .. $size) {
            $$paths[$i][$j] = '';
        }
    }
    foreach my $d (1 .. $max_length - 1) {
        my $new_paths = [];
        my $new_scores = [];
        copy_array($paths, $new_paths);
        copy_array($scores, $new_scores);
        foreach my $i (1 .. $size) {
            foreach my $j (0 .. $size) {
                next if $i == $j;
                my $best_score = $$scores[$i][$j];
                my $best_path = $$paths[$i][$j];
                foreach my $k (1 .. $size) {
                    next if ($k == $i || $k == $j);
                    if ($$scores[$i][$k] + $$scores[$k][$j] > $best_score) {
                        my $path = $$paths[$i][$k].($$paths[$i][$k] ? ' ' : '').$k.($$paths[$k][$j] ? ' ' : '').$$paths[$k][$j];
                        my $is_path = 1;
                        my %is_in_path;
                        foreach my $x (split /\s/, $path) {
                            if (defined $is_in_path{$x}) {
                                $is_path = 0;
                                last;
                            }
                            $is_in_path{$x} = 1;
                        }
                        next if !$is_path;
                        $best_score = $$scores[$i][$k] + $$scores[$k][$j];
                        $best_path = $path;
                    }
                }
                $$new_scores[$i][$j] = $best_score;
                $$new_paths[$i][$j] = $best_path;
            }
        }
        copy_array($new_paths, $paths);
        copy_array($new_scores, $scores);
    }
#    foreach my $i (1 .. $size) {
#        foreach my $j (0 .. $size) {
#            print STDERR "$$paths[$i][$j]   ";
#        }
#    }
}

sub find_best_cycles {
    my ($left_scores, $right_scores, $alignment_scores) = @_;
    my $left_size = $#$left_scores;
    my $right_size = $#$right_scores;
    my @left_best_paths;
    my @right_best_paths;
    foreach my $l (1 .. $left_size) {
        my @best_paths = sort {$$left_scores[$l][$b] <=> $$left_scores[$l][$a]} (0 .. $l-1, $l+1 .. $left_size);
        $left_best_paths[$l] = \@best_paths;
    }
    foreach my $r (1 .. $right_size) {
        my @best_paths = sort {$$right_scores[$r][$b] <=> $$right_scores[$r][$a]} (0 .. $r-1, $r+1 .. $right_size);
        $right_best_paths[$r] = \@best_paths;
    }
    my %cycle_score;
    foreach my $l (1 .. $left_size) {
        foreach my $li (0 .. min($left_size, 4) - 1) {
            my $l2 = $left_best_paths[$l][$li];
            foreach my $r (1 .. $right_size) {
                foreach my $ri (0 .. min($right_size, 4) - 1) {
                    my $r2 = $right_best_paths[$r][$ri];
                    $cycle_score{"$l $l2 $r $r2"} = $$left_scores[$l][$l2] + $$right_scores[$r][$r2]
                                                  + $$alignment_scores[$l][$r] + $$alignment_scores[$l2][$r2];
                }
            }
        }
    }
    my @cycles = sort {$cycle_score{$b} <=> $cycle_score{$a}} (keys %cycle_score);
    return \@cycles;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $source_tree = $bundle->get_tree( $self->language, 'a', $self->selector);
    my $target_tree = $bundle->get_tree( $self->to_language, 'a', $self->to_selector);
    my @source_nodes = $source_tree->get_descendants({'ordered' => 1});
    my @target_nodes = $target_tree->get_descendants({'ordered' => 1});
    my $source_length = scalar @source_nodes;
    my $target_length = scalar @target_nodes;
    return if $source_length < 2 || $target_length < 2;

    # get source matrix
    my @source_matrix;
    my $source_minimum = 0;
    my $source_total = 0; 
    foreach my $node (@source_nodes) {
        my @mst_scores = map {sprintf("%.2f",($_-$EDGE_PENALTY))} @{$node->wild()->{'mst_score'} || [0]};
        if ($#mst_scores != $source_length) {
            log_warn("mst-scores not filled properly at ".$node->id.".");
            @mst_scores = map {0} (0 .. $source_length);
        }
        foreach my $score (@mst_scores) {
            $source_minimum = $score if $score < $source_minimum;
            $source_total += $score;
        }
        $source_matrix[$node->ord] = \@mst_scores;
    }

    # get target matrix
    my @target_matrix;
    my $target_minimum = 0;
    my $target_total = 0;
    foreach my $node (@target_nodes) {
        my @mst_scores = map {sprintf("%.2f",($_-$EDGE_PENALTY))} @{$node->wild()->{'mst_score'} || [0]};
        if ($#mst_scores != $target_length) {
            log_warn("mst-scores not filled properly at ".$node->id.".");
            @mst_scores = map {0} (0 .. $target_length);
        }
        foreach my $score (@mst_scores) {
            $target_minimum = $score if $score < $target_minimum;
            $target_total += $score;
        }
        $target_matrix[$node->ord] = \@mst_scores;
    }

    # get alignment matrix
    my @alignment_matrix;
    foreach my $s_ord (0 .. $source_length) {
        foreach my $t_ord (0 .. $target_length) {
            $alignment_matrix[$s_ord][$t_ord] = 0;
        }
        next if $s_ord == 0;
        my ($alinodes, $alitypes) = $source_nodes[$s_ord - 1]->get_directed_aligned_nodes();
        foreach my $n (0 .. $#$alinodes) {
            my $t_ord = $$alinodes[$n]->ord;
            my $weight = $$alitypes[$n] =~ /int/ ? $ALIGNMENT_BONUS : 0;
            #my $weight = $$alitypes[$n] =~ /left/ ? $ALIGNMENT_BONUS : 0;
            #$weight += $$alitypes[$n] =~ /right/ ? $ALIGNMENT_BONUS : 0;
            $alignment_matrix[$s_ord][$t_ord] = $weight;
        }
    }

    my @left_paths;
    my @left_scores = @source_matrix;
    find_best_paths(\@left_scores, \@left_paths, 5);
   
    my @right_paths;
    my @right_scores = @target_matrix;
    find_best_paths(\@right_scores, \@right_paths, 5);

    my $cycles = find_best_cycles(\@left_scores, \@right_scores, \@alignment_matrix);

    my @left_parents;
    my @right_parents;

    foreach my $cycle (@$cycles) {
        my ($l, $l2, $r, $r2) = split /\s/, $cycle;
        my @l_path = ($l, split(/\s/, $left_paths[$l][$l2]), $l2);
        my @r_path = ($r, split(/\s/, $right_paths[$r][$r2]), $r2);
        # check attachment consistency
        my $consistent = 0;
        foreach my $i (1 .. $#l_path) {
            if (defined $left_parents[$l_path[$i-1]] && $left_parents[$l_path[$i-1]] != $l_path[$i]) {
                $consistent = 1;
                last;
            }
        }
        next if $consistent;
        foreach my $i (1 .. $#r_path) {
            if (defined $right_parents[$r_path[$i-1]] && $right_parents[$r_path[$i-1]] != $r_path[$i]) {
                $consistent = 1;
                last;
            }
        }
        next if $consistent;
        # check acyclicity
        my $makes_cycle = 0;
        my %is_on_l_path;
        map {$is_on_l_path{$l_path[$_]} = 1} (0 .. $#l_path - 1);
        my %is_on_r_path;
        map {$is_on_r_path{$r_path[$_]} = 1} (0 .. $#r_path - 1);
        my $n = $l_path[$#l_path];
        while ($left_parents[$n]) {
            if ($is_on_l_path{$left_parents[$n]}) {
                $makes_cycle = 1;
                last;
            }
            $n = $left_parents[$n];
        }
        next if $makes_cycle;
        $n = $r_path[$#r_path];
        while ($right_parents[$n]) {
            if ($is_on_r_path{$right_parents[$n]}) {
                $makes_cycle = 1;
                last;
            }
            $n = $right_parents[$n];
        }
        next if $makes_cycle;
        # add edges to the trees
        foreach my $i (1 .. $#l_path) {
            $left_parents[$l_path[$i-1]] = $l_path[$i];
        }
        foreach my $i (1 .. $#r_path) {
            $right_parents[$r_path[$i-1]] = $r_path[$i];
        }
        my $l_forms = $source_nodes[$l-1]->form . " ";
        my @left_inner_nodes = split /\s/, $left_paths[$l][$l2];
        map { $l_forms .= $source_nodes[$_-1]->form . " " } @left_inner_nodes; 
        $l_forms .= $l2 ? $source_nodes[$l2-1]->form : '<root>';
        my $r_forms = $target_nodes[$r-1]->form . " ";
        my @right_inner_nodes = split /\s/, $right_paths[$r][$r2];
        map { $r_forms .= $target_nodes[$_-1]->form . " " } @right_inner_nodes;
        $r_forms .= $r2 ? $target_nodes[$r2-1]->form : '<root>';
        print STDERR "$l_forms(".$left_scores[$l][$l2] .") $r_forms(".$right_scores[$r][$r2].") "
                   . "[$alignment_matrix[$l][$r] $alignment_matrix[$l2][$r2]]\n";
    }
    
    # copy left a-tree and flatten it
    my $new_source_tree = $bundle->create_tree($self->language, 'a', 'new');
    $source_tree->copy_atree($new_source_tree);
    foreach my $node ($new_source_tree->get_descendants) {
        $node->set_parent($new_source_tree);
    }

    # build left a-tree
    my @new_source_nodes = ($new_source_tree, $new_source_tree->get_descendants({ordered => 1}));
    foreach my $i (1 .. $source_length) {
        $left_parents[$i] = 0 if !defined $left_parents[$i];
        $new_source_nodes[$i]->set_parent($new_source_nodes[$left_parents[$i]]);
    }

    # copy right a-tree and flatten it
    my $new_target_tree = $bundle->create_tree($self->to_language, 'a', 'new');
    $target_tree->copy_atree($new_target_tree);
    foreach my $node ($new_target_tree->get_descendants) {
        $node->set_parent($new_target_tree);
    }

    # build right a-tree
    my @new_target_nodes = ($new_target_tree, $new_target_tree->get_descendants({ordered => 1}));
    foreach my $i (1 .. $target_length) {
        $right_parents[$i] = 0 if !defined $right_parents[$i];
        $new_target_nodes[$i]->set_parent($new_target_nodes[$right_parents[$i]]);
    }
    print STDERR "\n";
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::MaxCycles

=head1 AUTHOR

David Marecek <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


