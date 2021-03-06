package Treex::Block::A2T::EN::MarkTextPronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::BaseMarkCoref';

#use Treex::Tool::Coreference::PerceptronRanker;
use Treex::Tool::ML::VowpalWabbit::Ranker;
use Treex::Tool::Coreference::EN::PronCorefFeatures;
use Treex::Tool::Coreference::NounAnteCandsGetter;
use Treex::Tool::Coreference::NodeFilter::PersPron;
use Treex::Tool::Coreference::Features::Container;
use Treex::Tool::Coreference::Features::Aligned;

has '+model_path' => (
    # $CZENG_COREF/tmp/ml/run_2015-04-04_12-44-16_9036.testing_on_English/001.8f801ad5b1.featset/001.134ca.mlmethod/model/train_00-18.pcedt_bi.en.analysed.ali-sup.vw.ranking.model
    default => 'data/models/coreference/EN/vowpal_wabbit/2015-04-04.perspron_3rd.mono_all.analysed.model',
);
has 'aligned_feats' => ( is => 'ro', isa => 'Bool', default => 0 );

override '_build_ranker' => sub {
    my ($self) = @_;
#    my $ranker = Treex::Tool::Coreference::PerceptronRanker->new( 
    my $ranker = Treex::Tool::ML::VowpalWabbit::Ranker->new( 
        { model_path => $self->model_path } 
    );
    return $ranker;
};

override '_build_feature_extractor' => sub {
    my ($self) = @_;
    my @container = ();
    
    my $en_fe = Treex::Tool::Coreference::EN::PronCorefFeatures->new();
    push @container, $en_fe;

    if ($self->aligned_feats) {
        my $aligned_fe = Treex::Tool::Coreference::Features::Aligned->new({
            feat_extractors => [ 
                Treex::Tool::Coreference::CS::PronCorefFeatures->new(),
            ],
            align_lang => 'cs',
            align_selector => 'src',
            align_types => ['supervised', '.*'],
        });
        push @container, $aligned_fe;
    }
    
    my $fe = Treex::Tool::Coreference::Features::Container->new({
        feat_extractors => \@container,
    });
    return $fe;
};

override '_build_ante_cands_selector' => sub {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::NounAnteCandsGetter->new({
        prev_sents_num => 1,
        anaphor_as_candidate => $self->anaphor_as_candidate,
        cands_within_czeng_blocks => 1,
        max_size => 100,
    });
    return $acs;
};

override '_build_anaph_cands_filter' => sub {
    my ($self) = @_;
    my $args = {
        skip_nonref => 1,
    };
    my $acf = Treex::Tool::Coreference::NodeFilter::PersPron->new({args => $args});
    return $acf;
};

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::MarkTextPronCoref

=head1 DESCRIPTION

Pronoun coreference resolver for English.
Settings:
* English personal pronoun filtering of anaphor
* candidates for the antecedent are nouns from current (prior to anaphor) and previous sentence
* English pronoun coreference feature extractor
* using a model trained by a perceptron ranker

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
