package Treex::Block::HamleDT::HI::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Lingua::Interset qw(decode);
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_features($root);
    $self->fix_root($root);
}



#------------------------------------------------------------------------------
# Features are stored in conll/feat and their format is not compatible with
# Universal Dependencies.
#------------------------------------------------------------------------------
sub fix_features
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $shakfeatures = $node->conll_feat();
        $shakfeatures = '' if(!defined($shakfeatures) || $shakfeatures eq '_');
        # Discard features with empty values.
        my @shakfeatures = grep {!m/-(any)?$/} (split(/\|/, $shakfeatures));
        # Some features will be preserved in the MISC field.
        my @miscfeatures;
        my @morfeatures;
        my $cat = '_';
        foreach my $feature (@shakfeatures)
        {
            if($feature =~ m/^(chunkId|chunkType|stype)-/)
            {
                $feature =~ s/^(.)/\u$1/;
                $feature =~ s/-/=/;
                push(@miscfeatures, $feature);
            }
            elsif($feature =~ m/^cat-(.*)$/)
            {
                $cat = $1;
            }
            elsif($feature =~ m/^(vib|tam)-/)
            {
                push(@morfeatures, $feature);
                $feature =~ s/^(.)/\u$1/;
                $feature =~ s/-/=/;
                push(@miscfeatures, $feature);
            }
            else
            {
                push(@morfeatures, $feature);
            }
        }
        # Convert the remaining features to Interset.
        # The driver hi::conll also expects the Hyderabad CPOS tag, which we now have in the POS column.
        my $conll_pos = $node->conll_pos();
        my $conll_feat = scalar(@morfeatures)>0 ? join('|', @morfeatures) : '_';
        my $src_tag = "$conll_pos\t$cat\t$conll_feat";
        my $f = decode('hi::conll', $src_tag);
        # Changed features may cause a change of UPOS but it is probably not desirable. Or is it?
        my $tag0 = $node->tag();
        my $tag1 = $f->get_upos();
        if($tag1 ne $tag0)
        {
            # Adjust Interset to the original tag.
            $f->set_upos($tag0);
            unless($tag1 eq 'X')
            {
                unshift(@miscfeatures, "AltTag=$tag0-$tag1");
            }
            # Only replace the original tag if it is an error.
            if($tag0 !~ m/^(NOUN|PROPN|PRON|ADJ|DET|NUM|VERB|AUX|ADV|ADP|CONJ|SCONJ|PART|INTJ|SYM|PUNCT|X)$/)
            {
                $node->set_tag($tag1);
            }
        }
        $node->set_iset($f);
        ###!!! We do not check the previous contents of MISC because we know that in this particular data it is empty.
        $node->wild()->{misc} = join('|', @miscfeatures);
    }
}



#------------------------------------------------------------------------------
# There is one case where a node depends on the root but its deprel is not
# 'root', or it does not depend on the root and its deprel is 'root'.
#------------------------------------------------------------------------------
sub fix_root
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->parent()->is_root() && $node->deprel() ne 'root')
        {
            $node->set_deprel('root');
        }
        elsif(!$node->parent()->is_root() && $node->deprel() eq 'root')
        {
            # The only occurrence I saw was a number attached to another number.
            # But let's do it a bit more general.
            if($node->is_numeral())
            {
                $node->set_deprel('nummod');
            }
            else
            {
                $node->set_deprel('dep');
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::HI::FixUD

This is a temporary block used to prepare the Hindi UD 1.2 treebank.
We got new data from Riyaz Ahmad / IIIT Hyderabad. The data is larger than the
previous Hindi data we had, and the dependency relations already follow the UD
guidelines. However, features have to be converted.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
