package Genome::VariantReporting::BamReadcount::MinCoverageFilter;

use strict;
use warnings FATAL => 'all';
use Genome;
use List::Util qw/first/;

class Genome::VariantReporting::BamReadcount::MinCoverageFilter {
    is => ['Genome::VariantReporting::Framework::Component::Filter', 'Genome::VariantReporting::BamReadcount::ComponentBase'],
    has => {
        min_coverage => {
            is => 'Number',
        },
    },
};

sub name {
    return 'min-coverage';
}

sub requires_experts {
    return ('bam-readcount');
}

sub filter_entry {
    my ($self, $entry) = @_;

    my $readcount_entry = $self->get_readcount_entry($entry);
    return return_hash($entry, 0) unless $readcount_entry;

    if ($readcount_entry->depth >= $self->min_coverage) {
        return return_hash($entry, 1);
    }
    return return_hash($entry, 0);
}

sub return_hash {
    my $entry = shift;
    my $pass = shift;

    my %return_hash;
    for my $alt (@{$entry->{alternate_alleles}}) {
        $return_hash{$alt} = $pass;
    }
    return %return_hash;
}

1;