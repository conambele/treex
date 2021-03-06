package Treex::Tool::Coreference::NodeFilter::PersPron;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

with 'Treex::Tool::Coreference::NodeFilter';

#my %BANNED_PRONS = map {$_ => 1} qw/
#    i me my mine myself you your yours yourself yourselves we us our ours ourselves one
#/;
my %THIRD_PERS_PRONS = map {$_ => 1} qw/
    he him his himself
    she her hers herself
    it its itself
    they them their theirs themselves
/;
my %PERS_PRONS_REFLEX = (
    en => { map {$_ => 1} qw/
            myself yourself himself herself itself ourselves yourselves themselves
          /},
    cs => { map {$_ => 1} qw/
            se svůj
          /},
);

has 'args' => (is => "ro", isa => "HashRef", default => sub {{}});

sub is_candidate {
    my ($self, $tnode) = @_;
    return is_3rd_pers($tnode, $self->args);
}

sub is_3rd_pers {
    my ($node, $args) = @_;
    $args //= {};

    if ($node->language eq 'cs') {
        return _is_3rd_pers_cs($node, $args);
    }
    if ($node->language eq 'en') {
        my $is_pers = _is_3rd_pers_en($node, $args);
        #if ($is_pers) {
        #    my $anode = $tnode->get_lex_anode;
        #    print "ALEMMA: " . $anode->lemma . "\n";
        #    print "AFORM: " . $anode->form . "\n";
        #}
        return $is_pers;
    }
}

# possible args:
#   skip_nonref : skip personal pronouns that are labeled as non-referential
#   reflexive : include reflexive pronouns (default = 1)
sub _is_3rd_pers_cs {
    my ($node, $args) = @_;

    if ($node->get_layer eq "a") {
        return 0;
    }
    else {
        return _is_3rd_pers_cs_t($node, $args);
    }
}

# processing ternary arguments for binary indicators
# arg = 0 : does not take the indicator into account
# arg = 1 : indicator must be true
# arg = -1 : indicator must be false
sub ternary_arg {
    my ($arg, $indicator) = @_;
    if ($arg > 0) {
        return $indicator;
    }
    elsif ($arg < 0) {
        return !$indicator;
    }
    else {
        return 1;
    }
}

sub _is_3rd_pers_cs_a {
    my ($anode, $args) = @_;

    # is pronoun
    my $is_perspron = $anode->tag =~ /^P[PHS05678]/;
    return 0 if (!$is_perspron);

    # is 3rd person
    my $is_3rd_person = $anode->tag =~ /^.......[^12]/;
    return 0 if (!$is_3rd_person);

    # return only expressed by default
    my $expressed = $args->{expressed} // 1;
    return 0 if ($expressed < 0);
    
    # reflexive
    my $arg_reflexive = $args->{reflexive} // 0;
    my $reflexive = is_reflexive($anode);
    return 0 if !ternary_arg($arg_reflexive, $reflexive);

    # possessive
    my $arg_possessive = $args->{possessive} // 0;
    my $possessive = is_possessive($anode);
    return 0 if !ternary_arg($arg_possessive, $possessive);
   
    return 1;
}

sub _is_3rd_pers_cs_t {
    my ($tnode, $args) = @_;

    # return only expressed by default
    my $arg_expressed = $args->{expressed} // 1;
    my $anode = $tnode->get_lex_anode;
    my $expressed = defined $anode;
    return 0 if !ternary_arg($arg_expressed, $expressed);
    #log_info "_is_3rd_pers_cs_t";

    
    # is in 3rd person
    my $is_3rd_pers = 1;
    if ( defined $tnode->gram_person ) {
        $is_3rd_pers = ($tnode->gram_person eq '3' || $tnode->gram_person eq 'inher');
    }
    elsif (defined $anode) {
        my $person = substr $anode->tag, 7, 1;
        $is_3rd_pers = ($person ne '1') && ($person ne '2');
    }
    #else {
    #    my $par = $tnode->get_parent;
    #    my $apar = $par->get_lex_anode;
    #    if (defined $apar) {
    #        my $person = substr $apar->tag, 7, 1;
    #        if ($person ne "-") {
    #            $is_3rd_pers = $person eq '3';
    #        }
    #    }
    #}
    #log_info $tnode->id . "\tis_3rd: " . ($is_3rd_pers?1:0);


    # reflexive
    my $arg_reflexive = $args->{reflexive} // 0;
    my $reflexive = is_reflexive($tnode);
    return 0 if !ternary_arg($arg_reflexive, $reflexive);
    
    # possessive
    my $arg_possessive = $args->{possessive} // 0;
    my $possessive = is_possessive($tnode);
    return 0 if !ternary_arg($arg_possessive, $possessive);
    
    # skip non-referential
    my $ok_skip_nonref = 1;
    if ($args->{skip_nonref}) {
        my $is_refer = $tnode->wild->{referential};
        $ok_skip_nonref = !defined $is_refer || ($is_refer == 1);
    }

    return (
        ($tnode->t_lemma eq '#PersPron') &&  # personal pronoun 
        $is_3rd_pers &&    # third person
        $ok_skip_nonref  # referential (if it's set)
    );
}


# possible args:
#   skip_nonref : skip personal pronouns that are labeled as non-referential
#   reflexive : include reflexive pronouns (default = 1)
sub _is_3rd_pers_en {
    my ($node, $args) = @_;

    if ($node->get_layer eq "a") {
        return _is_3rd_pers_en_a($node, $args);
    }
    else {
        return _is_3rd_pers_en_t($node, $args);
    }
}

sub _is_3rd_pers_en_t {
    my ($tnode, $args) = @_;

    # is expressed on the surface
    my $arg_expressed = $args->{expressed} // 1;
    my $anode = $tnode->get_lex_anode;
    my $expressed = defined $anode;
    return 0 if !ternary_arg($arg_expressed, $expressed);
    
    # is in 3rd person
    # by default generated #PersPron with no gram_person set are in 3rd person
    my $is_3rd_pers = 1;
    if ( defined $tnode->gram_person ) {
        $is_3rd_pers = ($tnode->gram_person eq '3');
    }
    elsif (defined $anode) {
        $is_3rd_pers = (defined $THIRD_PERS_PRONS{$anode->lemma});
    }

    # reflexive
    my $arg_reflexive = $args->{reflexive} // 0;
    my $reflexive = is_reflexive($tnode);
    return 0 if !ternary_arg($arg_reflexive, $reflexive);
    
    # possessive
    my $arg_possessive = $args->{possessive} // 0;
    my $possessive = is_possessive($tnode);
    return 0 if !ternary_arg($arg_possessive, $possessive);
    
    # skip non-referential
    my $ok_skip_nonref = 1;
    if ($args->{skip_nonref}) {
        my $is_refer = $tnode->wild->{referential};
        $ok_skip_nonref = !defined $is_refer || ($is_refer == 1);
    }

    return (
        ($tnode->t_lemma eq '#PersPron') &&  # personal pronoun 
        $is_3rd_pers &&    # third person
        $ok_skip_nonref  # referential (if it's set)
    );
}

sub _is_3rd_pers_en_a {
    my ($anode, $args) = @_;
    
    # is central (sometimes called personal)  pronoun
    my $is_perspron = $THIRD_PERS_PRONS{$anode->lemma};
    return 0 if (!$is_perspron);
    
    # return only expressed by default
    my $expressed = $args->{expressed} // 1;
    return 0 if ($expressed < 0);
    
    # reflexive
    my $arg_reflexive = $args->{reflexive} // 0;
    my $reflexive = is_reflexive($anode);
    return 0 if !ternary_arg($arg_reflexive, $reflexive);

    # possessive
    my $arg_possessive = $args->{possessive} // 0;
    my $possessive = is_possessive($anode);
    return 0 if !ternary_arg($arg_possessive, $possessive);
   
    return 1;
}

sub is_reflexive {
    my ($node) = @_;
    my $anode;
    if ($node->get_layer eq "t") {
        my $t_reflex = $node->get_attr('is_reflexive');
        return $t_reflex if (defined $t_reflex);
        $anode = $node->get_lex_anode;
    }
    else {
        $anode = $node;
    }
    
    return 0 if (!defined $anode);
    my $lemma = $anode->lemma;
    if ($anode->language eq "cs") {
        $lemma = Treex::Tool::Lexicon::CS::truncate_lemma($lemma, 1);
    }
    return $PERS_PRONS_REFLEX{$anode->language}{$lemma};
}

sub is_possessive {
    my ($node) = @_;
    my $anode;
    if ($node->get_layer eq "t") {
        $anode = $node->get_lex_anode;
    }
    else {
        $anode = $node;
    }
    return 0 if (!defined $anode);
    if ($anode->language eq "en") {
        return $anode->tag eq 'PRP$';
    }
    elsif ($anode->language eq "cs") {
        return $anode->tag =~ /^.[18SU]/;
    }
    return 0;
}

# TODO doc

1;
