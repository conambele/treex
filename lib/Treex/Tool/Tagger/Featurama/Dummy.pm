package Treex::Tool::Tagger::Featurama::Dummy;
use Moose;

extends 'Treex::Tool::Tagger::Featurama';
override '_analyze' => sub {
    my ( $self, $wordform ) = @_;
    return (
        { tag => 'NN',  lemma => $wordform },
        { tag => 'NNP', lemma => $wordform },
        { tag => 'VBP', lemma => $wordform },
        { tag => 'JJ',  lemma => $wordform },
        { tag => 'WRB', lemma => $wordform },
        { tag => '.',   lemma => $wordform },
        { tag => 'PRP', lemma => $wordform },
    );
};

override '_get_feature_names' => sub {
    return qw(Form Prefix1 Prefix2 Prefix3 Prefix4 Prefix5 Prefix6 Prefix7 Prefix8 Prefix9 Suffix1 Suffix2 Suffix3 Suffix4 Suffix5 Suffix6 Suffix7 Suffix8 Suffix9 Num Cap Dash Tag);
};

override '_get_features' => sub {
    my ( $self, $wordforms, $analyses, $index ) = @_;
    my $wordform = $wordforms->[$index];
    my $analysis_rf = $analyses->[$index];
    my @features;

    #Form
    push( @features, $wordform );

    #Prefixes
    push( @features, substr( $wordform, 0, 1 ) );
    push( @features, substr( $wordform, 0, 2 ) );
    push( @features, substr( $wordform, 0, 3 ) );
    push( @features, substr( $wordform, 0, 4 ) );
    push( @features, substr( $wordform, 0, 5 ) );
    push( @features, substr( $wordform, 0, 6 ) );
    push( @features, substr( $wordform, 0, 7 ) );
    push( @features, substr( $wordform, 0, 8 ) );
    push( @features, substr( $wordform, 0, 9 ) );

    #Suffixes
    push( @features, substr( $wordform, -1, 1 ) );
    push( @features, substr( $wordform, -2, 2 ) );
    push( @features, substr( $wordform, -3, 3 ) );
    push( @features, substr( $wordform, -4, 4 ) );
    push( @features, substr( $wordform, -5, 5 ) );
    push( @features, substr( $wordform, -6, 6 ) );
    push( @features, substr( $wordform, -7, 7 ) );
    push( @features, substr( $wordform, -8, 8 ) );
    push( @features, substr( $wordform, -9, 9 ) );

    #Num
    push( @features, $wordform =~ /[0-9]/ ? 1 : 0 );

    #Cap
    push( @features, $wordform =~ /[[:upper:]]/ ? 1 : 0 );

    #Dash
    push( @features, $wordform =~ /-/ ? 1 : 0 );

    # Tag
    push( @features, "NULL" );

    # Analyses
    push @features, map { $_->{'tag'} } @{$analysis_rf};
    return @features;
};

override '_extract_tag_and_lemma' => sub {
    my ( $self, $index, $wordform ) = @_;
    return {
        tag => $self->perc->getProposedTag( $index, 0 ),
        lemma => $wordform,
    };
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Tagger::Featurama::Dummy

=head1 DESCRIPTION

Dummy language for Featurama

=head2 OVERRIDEN METHODS

=over

=item _analyze($wordform)

Returns some PennTreeBank tags plus original form as a lemma

=item _get_feature_names()

Returns feature names for English

=item _get_features($wordform, $analyses_rf)

Returns features for English

=item _extract_tag_and_lemma($index, $wordform)

Returns proposed tag and wordform

=back

=head1 AUTHORS

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

