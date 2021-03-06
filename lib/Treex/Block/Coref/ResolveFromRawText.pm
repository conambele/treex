package Treex::Block::Coref::ResolveFromRawText;
use Moose::Role;
use utf8;
use Treex::Core::Common;

has 'is_czeng' => ( is => 'ro', isa => 'Bool', required => 1 );

requires '_process_bundle_block';
requires '_prepare_raw_text';

sub process_document {
    my ($self, $doc) = @_;

    my ($bundle_blocks, $block_ids) = $self->_get_bundle_blocks($doc);

    for (my $i = 0; $i < @$bundle_blocks; $i++) {
        $self->_process_bundle_block($block_ids->[$i], $bundle_blocks->[$i]);
    }
}

sub _get_bundle_blocks {
    my ($self, $doc) = @_;
    my @bundles = $doc->get_bundles;
    my @bundle_blocks = ();
    my @block_ids = ();
    my @texts = ();
    if ($self->is_czeng) {
        my $prev_block_id = undef;
        my @curr_block_bundles = ();
        foreach my $bundle (@bundles) {
            my $curr_block_id = $bundle->attr('czeng/blockid');
            if (defined $prev_block_id && defined $curr_block_id && $curr_block_id ne $prev_block_id ) {
                push @bundle_blocks, [ @curr_block_bundles ];
                push @block_ids, $prev_block_id;
                @curr_block_bundles = ();
            }
            if (defined $curr_block_id) {
                $prev_block_id = $curr_block_id;
            }
            else {
                log_warn "The bundle attribute 'czeng/blockid' is undefined. Adding bundle to the previous block.";
            }
            push @curr_block_bundles, $bundle;
        }
        if (@curr_block_bundles) {
            push @bundle_blocks, [ @curr_block_bundles ];
            push @block_ids, $prev_block_id;
        }
    }
    else {
        @bundle_blocks = ( \@bundles );
    }
    return (\@bundle_blocks, \@block_ids);
}

sub _is_prefix {
    my ($s1, $s2) = @_;

    return undef if (!defined $s1 || !defined $s2);
    #print STDERR "$s1 $s2\n";
    my $is_prefix;
    if (length($s1) > length($s2)) {
        $is_prefix = ($s1 =~ /^\Q$s2/);
    }
    else {
        $is_prefix = ($s2 =~ /^\Q$s1/);
    }
    return $is_prefix;
}

sub _is_superfluous {
    my ($str1, $str2) = @_;
    
    # TODO can be changed to check whether it's a suffix of a previous word
    return 1 if ($str1 eq '.');
    return -1 if ($str2 eq '.');
    return 0 if ($str1 eq "labor" && $str2 eq "labour");
    return 0 if ($str1 eq "-LRB-" && $str2 eq "(");
    return 0 if ($str1 eq "-RRB-" && $str2 eq ")");
    return 0 if ($str1 eq "theater" && $str2 eq "theatre");
    return 0 if ($str1 eq "labeled" && $str2 eq "labelled");
    return 0 if ($str1 eq "meager" && $str2 eq "meagre");
    #log_warn "Neither '$str1' nor '$str2' are superflous.";
    #log_fatal "Luxembourg-based" if ($str1 eq "Luxembourg-based" || $str2 eq "Luxembourg-based");
    return 0;
}
sub _align_arrays {
    my ($self, $a1, $a2) = @_;

    #print STDERR Dumper($a1, $a2);

    my %align = ();

    my $i1 = 0; my $i2 = 0;
    my $j1 = 0; my $j2 = 0;
    #my $l_offset = length($a1->[$i1][$j1]) - length($a2->[$i2][$j2]);
    my $l_offset = 0;
    #my $l1 = 0; my $l2 = 0;
    #print STDERR scalar @$a1 . "\n";
    #print STDERR scalar @$a2 . "\n";
    while (($i1 < scalar @$a1) && ($i2 < scalar @$a2)) {
        #print STDERR Dumper($a1->[$i1], $a2->[$i2]);
        while (($j1 < @{$a1->[$i1]}) && ($j2 < @{$a2->[$i2]})) {

            my $s1 = $a1->[$i1][$j1];
            my $s2 = $a2->[$i2][$j2];
            if ($l_offset == 0 && !_is_prefix($s1, $s2)) {
                my $superfl = _is_superfluous($s1, $s2);
                if ($superfl > 0) {
                    $j1++;
                    next;
                }
                elsif ($superfl < 0) {
                    $j2++;
                    next;
                }
                else {
                    # TODO: HACK
                    $l_offset -= length($s1) - length($s2);
                }
            }

            $l_offset += length($s1) - length($s2);
            if ($l_offset) {
                #print STDERR "$i1:$j1 -> $i2:$j2\t($l_offset)\t$s1 $s2\n";
            }
            $align{$i1.",".$j1} = $i2.",".$j2 if (!defined $align{$i1.",".$j1});
            
            if ($l_offset < 0) {
                $l_offset += length($s2);
                $j1++;
            }
            elsif ($l_offset > 0) {
                $l_offset -= length($s1);
                $j2++;
            }
            else {
                $j1++; $j2++;
            }
            #print STDERR Dumper(\%align);
            #print STDERR ($j1 < @{$a1->[$i1]}) ? 1 : 0;
            #print STDERR ($j2 < @{$a2->[$i2]}) ? 1 : 0;
            #print STDERR ($l_offset != 0) ? 1 : 0;
            #print STDERR "\n";
            #exit if ($j1 > 50 || $j2 > 50);
        }
        if ($j1 >= @{$a1->[$i1]}) {
            $i1++; $j1 = 0;
        }
        if ($j2 >= @{$a2->[$i2]}) {
            $i2++; $j2 = 0;
        }
        #my $line = <STDIN>;
    }

    return \%align;
}

1;
