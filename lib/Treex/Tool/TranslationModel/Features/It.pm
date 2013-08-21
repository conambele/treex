package Treex::Tool::TranslationModel::Features::It;

use Moose;

use Treex::Core::Common;
use Treex::Tool::Storage::Storable;

extends 'Treex::Core::Block';

has 'adj_compl_path' => (is => 'ro', isa => 'Str', required => 1);
has 'verb_func_path' => (is => 'ro', isa => 'Str', required => 1);

has '_adj_compl_list' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_adj_compl_list',
);

has '_verb_func_counts' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_verb_func_counts',
);

sub BUILD {
    my ($self) = @_;
    $self->_adj_compl_list;
}

sub _build_adj_compl_list {
    my ($self) = @_;
    return Treex::Tool::Storage::Storable::load_obj($self->adj_compl_path);
}

sub _build_verb_func_counts {
    my ($self) = @_;
    return Treex::Tool::Storage::Storable::load_obj($self->verb_func_path);
}

sub _bucketing {
    my ($value, $categs, $buckets) = @_;

    # return value if it's categorial
    my %categ_hash = map {$_ => 1} @$categs;
    return $value if $categ_hash{$value};

    return scalar (grep {$value < $_} @$buckets);
}

sub _get_nada_refer {
    my ($tnode) = @_;
    my $refer = $tnode->wild->{'referential'};
    return '__UNDEF__' if (!defined $refer);
    return $refer;
}

sub _get_parent_lemma {
    my ($tnode) = @_;
    my $par = $tnode->get_parent;
    if ($par->is_root) {
        return "__ROOT__";
    }
    return $par->t_lemma;
}

sub _it_subj {
    my ($tnode) = @_;
    return $tnode->formeme =~ /subj/ ? 1 : 0;
}

sub _sibl_obj {
    my ($tnode) = @_;
    my ($sibl) = grep {$_->formeme =~ /obj/} $tnode->get_siblings;
    return $sibl ? 1 : 0;
}

sub _cleft {
    my ($tnode, $approx) = @_;
    my $it_subj_be = _it_subj($tnode) && (_get_parent_lemma($tnode) eq "be");
    return 0 if !$it_subj_be;
    
    my ($obj) = grep {$_->formeme =~ /obj/} $tnode->get_siblings;
    return 0 if !$obj;

    my @rc_cands;
    if ($approx) {
        @rc_cands = grep {$_->get_depth - $obj->get_depth < 3} $obj->get_descendants
    } else {  
        @rc_cands = $obj->get_echildren;
    }
    my ($rc) = grep {$_->formeme eq "v:rc"} @rc_cands;
    return $rc ? 1 : 0;
}

sub _be_adjcompl {
    my ($tnode) = @_;
    my $it_subj_be = _it_subj($tnode) && (_get_parent_lemma($tnode) eq "be");
    return 0 if !$it_subj_be;
    
    my ($adjcompl) = grep {$_->formeme =~ /adj:compl/} $tnode->get_siblings;
    return $adjcompl ? 1 : 0;
}

sub _be_adjcompl_that {
    my ($tnode) = @_;
    my $adjcompl = _be_adjcompl($tnode);

    my ($vthat) = grep {$_->formeme =~ /v:that/} $tnode->get_siblings;
    return ($adjcompl && $vthat) ? 1 : 0;
}
sub _be_adjcompl_to {
    my ($tnode) = @_;
    my $adjcompl = _be_adjcompl($tnode);

    my ($vto) = grep {$_->formeme =~ /v:to\+inf/} $tnode->get_siblings;
    return ($adjcompl && $vto) ? 1 : 0;
}

my $ADJCOMPL_THAT_THRESHOLD = 1;
my $ADJCOMPL_TO_THRESHOLD = 1;
sub _be_adjcompl_that_inlist {
    my ($self, $tnode) = @_;
    my $it_subj_be = _it_subj($tnode) && (_get_parent_lemma($tnode) eq "be");
    return 0 if !$it_subj_be;
    
    my ($adjcompl) = grep {$_->formeme =~ /adj:compl/} $tnode->get_siblings;
    return 0 if !$adjcompl;
    my ($vthat) = grep {$_->formeme =~ /v:that/} $tnode->get_siblings;
    return 0 if !$vthat;
    my $count = $self->_adj_compl_list->{"v:that+fin"}{$adjcompl->t_lemma} || 0;
    return $count > $ADJCOMPL_THAT_THRESHOLD ? 1 : 0;
}
sub _be_adjcompl_to_inlist {
    my ($self, $tnode) = @_;
    my $it_subj_be = _it_subj($tnode) && (_get_parent_lemma($tnode) eq "be");
    return 0 if !$it_subj_be;
    
    my ($adjcompl) = grep {$_->formeme =~ /adj:compl/} $tnode->get_siblings;
    return 0 if !$adjcompl;
    my ($vto) = grep {$_->formeme =~ /v:to\+inf/} $tnode->get_siblings;
    return 0 if !$vto;
    my $count = $self->_adj_compl_list->{"v:to+inf"}{$adjcompl->t_lemma} || 0;
    return $count > $ADJCOMPL_TO_THRESHOLD ? 1 : 0;
}

sub _be_adjcompl_none {
    my ($tnode) = @_;
    my $adjcompl = _be_adjcompl($tnode);

    my ($vthat) = grep {$_->formeme =~ /v:that/} $tnode->get_siblings;
    my ($vto) = grep {$_->formeme =~ /v:to\+inf/} $tnode->get_siblings;
    return ($adjcompl && !$vthat && !$vto) ? 1 : 0;
}

sub _be_adjcompl_smt {
    my ($tnode) = @_;
    my $adjcompl = _be_adjcompl($tnode);
    return "undef" if !$adjcompl;

    my ($vthat) = grep {$_->formeme =~ /v:that/} $tnode->get_siblings;
    return "that" if $vthat;
    my ($vto) = grep {$_->formeme =~ /v:to\+inf/} $tnode->get_siblings;
    return "to" if $vthat;
    return "none";
}

sub _is_coref {
    my ($tnode) = @_;

    my ($ante) = $tnode->get_coref_text_nodes;
    return $ante ? 1 : 0;
}

sub _has_vp_ante {
    my ($tnode) = @_;

    my @antes = $tnode->get_coref_chain;
    return "undef" if (@antes == 0);

    #print STDERR "COREF_CHAIN: " . (join ",", map {$_->t_lemma} @antes) . "\n";
    my ($vp_ante) = grep {$_->formeme && $_->formeme =~ /^v/} @antes;
    return $vp_ante ? 1 : 0;
}

sub _get_par_lemma_adj {
    my ($tnode) = @_;
    my $par = $tnode->get_parent;
    return "__ROOT__" if $par->is_root;
    
    my $par_lemma = $par->t_lemma;
    if ($par_lemma eq "be") {
        my ($adj) = grep {$_->formeme && $_->formeme =~ /adj/} $par->get_children;
        $par_lemma .= "_" . $adj->t_lemma if $adj;
    }
    return $par_lemma;
}

sub _verb_func_en {
    my ($self, $tnode, $it) = @_;

    my $par_lemma = _get_par_lemma_adj($tnode);
    my $func = $tnode->functor;
    my $en_verb_func = $par_lemma . ":" . $func;

    my $en_verb_func_c = $self->_verb_func_counts->{en_verb_func}{$en_verb_func};
    my $it_c = $self->_verb_func_counts->{it}{$it};
    my $en_verb_func_it_c = $self->_verb_func_counts->{en_verb_func_it}{$en_verb_func}{$it} || 0;

    return "undef" if (!$it_c || !$en_verb_func_c);
    return "-Inf" if !$en_verb_func_it_c;

    my $value = log ($en_verb_func_it_c / ($en_verb_func_c * $it_c));

    return sprintf "%.5f", $value;
}

sub get_features {
    my ($self, $tnode) = @_;

    my %feats = ();

    ######### FEATURES #############
    

    $feats{nada_refer} = _get_nada_refer($tnode);
    $feats{par_lemma} = _get_parent_lemma($tnode);
    
    $feats{par_be} = $feats{par_lemma} eq "be" ? 1 : 0;
    $feats{it_subj} = _it_subj($tnode);
    $feats{it_subj_be} = $feats{it_subj} && $feats{par_be} ? 1 : 0;
    $feats{it_subj_be} = $feats{it_subj} && $feats{par_be} ? 1 : 0;
    $feats{sibl_obj} = _sibl_obj($tnode);
    $feats{it_subj_be_obj} = $feats{it_subj_be} && $feats{sibl_obj} ? 1 : 0;

    # cleft sentences:
    # But it is Mr. Lane, as movie director, producer and writer, who has been obsessed with refitting Chaplin's Little Tramp in a contemporary way.
    # Then an announcer interjects: ``It was Douglas Wilder who introduced a bill to force rape victims age 13 and younger to be interrogated about their private lives by lawyers for accused rapists.
    # And most disturbing, it is educators, not students, who are blamed for much of the wrongdoing.
    $feats{cleft} = _cleft($tnode, 0);
    $feats{cleft_approx} = _cleft($tnode, 1);

    # it + be + adj:compl + v:that+fin
    # If the banks exhaust all avenues of appeal, it is possible that they would seek to have the illegality ruling work both ways, some market sources said .
    $feats{be_adjcompl} = _be_adjcompl($tnode);
    $feats{be_adjcompl_that} = _be_adjcompl_that($tnode);
    $feats{be_adjcompl_to} = _be_adjcompl_to($tnode);
    $feats{be_adjcompl_that_inlist} = $self->_be_adjcompl_that_inlist($tnode);
    $feats{be_adjcompl_to_inlist} = $self->_be_adjcompl_to_inlist($tnode);
    $feats{be_adjcompl_none} = _be_adjcompl_none($tnode);
    $feats{be_adjcompl_smt} = _be_adjcompl_smt($tnode);

    # exploiting coreference
    $feats{is_coref} = _is_coref($tnode);
    $feats{has_vp_ante} = _has_vp_ante($tnode);

    # verb-func-it from CzEng
    $feats{verb_func_en_pp} = $self->_verb_func_en($tnode, '#PersPron');
    $feats{verb_func_en_pp_buck} = _bucketing($feats{verb_func_en_pp}, ["-Inf","undef"], [-14, -12, -11, -10.5, -10]);
    $feats{verb_func_en_ten} = $self->_verb_func_en($tnode, 'ten');
    $feats{verb_func_en_ten_buck} = _bucketing($feats{verb_func_en_ten}, ["-Inf","undef"], [-14, -12.5, -11.5, -10.5, -10]);

    # TODO:many more features

    ###############################
    my @feat_list = map {$_ . "=" . $feats{$_}} sort keys %feats;

    my $address = $tnode->get_address;
    return ("address=$address", @feat_list);
}

1;
