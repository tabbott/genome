package Genome::VariantReporting::Report::FullReport;

use strict;
use warnings;
use Genome;
use List::Util qw( min );
use Genome::VariantReporting::Suite::BamReadcount::VafInterpreterHelpers qw(single_vaf_headers per_library_vaf_headers);

class Genome::VariantReporting::Report::FullReport {
    is => [ 'Genome::VariantReporting::Report::WithHeader', 'Genome::VariantReporting::Framework::Component::WithManySampleNames', 'Genome::VariantReporting::Framework::Component::WithManyLibraryNames'],
    doc => "Extensive tab-delimited report covering a set of one or more samples",
};

sub name {
    return 'full';
}

sub required_interpreters {
    return qw(position vep info-tags variant-type min-coverage min-coverage-observed max-vaf-observed variant-callers many-samples-vaf rsid caf);
}

sub headers {
    my $self = shift;
    my @headers = qw/
        chromosome_name
        start
        stop
        reference
        variant
        variant_type
        transcript_name
        trv_type
        trv_type_category
        amino_acid_change
        default_gene_name
        ensembl_gene_id
        inSegDup
        AML_RMG
        rsid
        caf
        max_alt_af
        onTarget
        MeetsMinDepthCutoff
    /;

    push @headers, single_vaf_headers([$self->sample_names]);

    push @headers, qw/
        min_coverage_observed
        max_normal_vaf_observed
        max_tumor_vaf_observed
        variant_callers
        variant_caller_count
    /;

    push @headers, per_library_vaf_headers([$self->library_names]);

    return @headers;
}

sub _header_to_info_tag_conversion {
    return {
        AML_RMG => 'AML_RMG',
        inSegDup => 'SEG_DUP',
        onTarget => 'ON_TARGET',
    }
}

sub report {
    my $self = shift;
    my $interpretations = shift;

    my %fields = $self->available_fields_dict();
    for my $allele (keys %{$interpretations->{($self->required_interpreters)[0]}}) {
        my @line_fields;
        for my $header ($self->headers()) {
            my $interpreter = $fields{$header}->{interpreter};
            my $field = $fields{$header}->{field};

            if ($header eq 'inSegDup' || $header eq 'onTarget' || $header eq 'AML_RMG') {
                my $info_tags = $interpretations->{$interpreter}->{$allele}->{$field};
                push @line_fields, $self->_get_info_tag(_header_to_info_tag_conversion()->{$header}, $info_tags);
            }
            elsif ($header eq 'variant_callers') {
                my @variant_callers = @{$interpretations->{$interpreter}->{$allele}->{$field}};
                push @line_fields, $self->_format(join(", ", @variant_callers));
            }
            elsif ($header =~ /per_library/) {
                my @libraries = split ",", $interpretations->{$interpreter}->{$allele}->{$field};
                my $value_for_header;
                for my $library (@libraries) {
                    my ($name, $value) = split ":", $library;
                    my $pattern = $name."_per_library";
                    if ($header =~ /^$pattern/) {
                        $value_for_header = $value;
                        last;
                    }
                }
                push @line_fields, $self->_format($value_for_header);
            }
            # If we don't have an interpreter that provides this field, handle it cleanly if the field is known unavailable
            elsif ($self->header_is_unavailable($header)) {
                push @line_fields, $self->_format();
            }
            elsif ($interpreter) {
                push @line_fields, $self->_format($interpretations->{$interpreter}->{$allele}->{$field});
            }
            else {
                # We use $header here because $field will be undefined due to it not being in an interpreter
                die $self->error_message("Field (%s) is not available from any of the interpreters provided", $header);
            }
        }
        $self->_output_fh->print(join("\t", @line_fields) . "\n");
    }
}
sub available_fields_dict {
    my $self = shift;

    my %available_fields = $self->SUPER::available_fields_dict();
    for my $info_tag_field (qw/inSegDup onTarget AML_RMG/) {
        $available_fields{$info_tag_field} = {
            interpreter => 'info-tags',
            field => 'info_tags',
        };
    }

    for my $per_library_field (per_library_vaf_headers([$self->library_names])) {
        my ($library_name, $generic_field_name) = $per_library_field =~ m/(.*)_(per_library.*)/;
        my $library = Genome::Library->get(name => $library_name);
        $available_fields{$per_library_field} = {
            interpreter => 'many-samples-vaf',
            field => $self->create_sample_specific_field_name($generic_field_name, $library->sample_name),
        };
    }

    $available_fields{MeetsMinDepthCutoff} = {
        interpreter => 'min-coverage',
        field => 'filter_status',
    };
    return %available_fields;
}

sub _get_info_tag {
    my ($self, $info_tag, $info_tags_string) = @_;

    if ($info_tags_string =~ /$info_tag/) {
        return $self->_format(1);
    }
    else {
        return $self->_format(0);
    }
}

1;
