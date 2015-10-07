package Treex::Block::T2T::EN2EU::FixThereIs;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
	my ( $self, $t_node ) = @_;

	#there is edo there are aurkitzean, gazteleraz haber edo estar jartzen da
	my $src_t_node = $t_node->src_tnode;
	my @def;
	my @children;
	if (defined($src_t_node))
	{
	    @children = $src_t_node->get_children();
	    if ($src_t_node->t_lemma eq "be" && (grep {$_->lemma eq "there"} $src_t_node->get_aux_anodes))
	    {

		$t_node->set_t_lemma('egon');

		my $new_node = $t_node->create_child(
		    {   't_lemma'       => '#PersPron',
			'form'          => '',
			'functor'       => 'ACT',
			'gram/number'   => 'sg',
			'gram/person'   => '3',
			'gram/sempos'   => 'n.pron.def.pers',
			'clause_number' => $t_node->clause_number,
			'formeme'       => 'n:subj',
			'is_generated'  => '1',
			'nodetype'      => 'complex'
		    }
		    );

		$new_node->shift_before_subtree($t_node);
	    }
	}

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2EU::FixThereIs

=head1 DESCRIPTION

Creates a PersPron node for the 'there is/are' 

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.




