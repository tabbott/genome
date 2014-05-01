package Genome::Annotation::ReportGeneratorWrapper;

use strict;
use warnings FATAL => 'all';
use Genome;

class Genome::Annotation::ReportGeneratorWrapper {
    is => 'Command::V2',

    has_input => [
        build_id => {
            is => 'Text',
        },
        variant_type => {
            is => 'Text',
            is_output => 1,
            valid_values => ['snvs', 'indels'],
        },
        input_result => {
            is => 'Genome::SoftwareResult',
        },
        output_directory => {
            is => 'Path',
            is_output => 1,
        },
    ],
};

sub execute {
    my $self = shift;

    Genome::Annotation::ReportGenerator->execute(
        vcf_file => $self->input_result->output_file_path,
        plan => $self->plan,
        output_directory => $self->output_directory,
        variant_type => $self->variant_type,
        translations => $self->translations,
    );
    return 1;
}

sub plan {
    my $self = shift;

    return $self->build->annotation_plan($self->variant_type);
}

sub translations {
    my $self = shift;
    my $result = {};

    if ($self->build->isa('Genome::Model::Build::SomaticValidation')) {
        $result->{'tumor'} = $self->build->tumor_sample->name;
    }
    if ($self->build->isa('Genome::Model::Build::SomaticVariation')) {
        $result->{'tumor'} = $self->build->tumor_build->subject->name;
    }
    return $result;
}

sub build {
    my $self = shift;

    my $build = Genome::Model::Build->get($self->build_id);
    if ($build) {
        return $build;
    } else {
        die $self->error_message("Couldn't find a build for id (%s)",
            $self->build_id);
    }
}


1;