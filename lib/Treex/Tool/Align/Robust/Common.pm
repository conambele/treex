package Treex::Tool::Align::Robust::Common;

use Moose;
use Treex::Core::Common;

sub filter_by_functor {
    my ($nodes, $functor, $errors) = @_;
    my @functor_tnodes = grep {$_->functor eq $functor} @$nodes;
    if (!@functor_tnodes) {
        push @$errors, "NO_FUNCTOR_TNODE";
        return;
    }
    return @functor_tnodes;
}

sub eparents_of_aligned_siblings {
    my ($siblings, $errors) = @_;
    my ($epar, @epars) = unique([map {$_->get_eparents({or_topological => 1})} @$siblings]);
    if (@epars > 0) {
        push @$errors, "MANY_SIBLINGS_PARENTS";
        return;
    }
    return $epar;
}

sub parents_of_aligned_siblings {
    my ($siblings, $errors) = @_;
    my ($par, @pars) = unique([map {$_->get_parent} @$siblings]);
    if (@pars > 0) {
        push @$errors, "MANY_SIBLINGS_PARENTS";
        return;
    }
    return $par;
}

1;
