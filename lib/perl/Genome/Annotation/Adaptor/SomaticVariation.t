#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Test::Deep;
use Sub::Install qw(reinstall_sub);
use Genome::Test::Factory::Model::SomaticVariation;

my $pkg = "Genome::Annotation::Adaptor::SomaticVariation";
use_ok($pkg);

my ($build, $bam_result1, $bam_result2, $snv_vcf_result, $indel_vcf_result) = setup_objects();

subtest "With and without vcf results" => sub {
    my $cmd = Genome::Annotation::Adaptor::SomaticVariation->create(build => $build);
    ok($cmd->isa('Genome::Annotation::Adaptor::SomaticVariation'), "Command created correctly");
    ok($cmd->execute, "Command executed successfully");
    cmp_bag([$cmd->bam_results], [$bam_result1, $bam_result2], "Bam results set as expected");
    is_deeply($cmd->annotation_build, $build->annotation_build, "Annotation build set as expected");
    is($cmd->snv_vcf_result, undef, "snv vcf result is not defined");
    is($cmd->indel_vcf_result, undef, "indel vcf result is not defined");

    add_vcf_results($snv_vcf_result, $indel_vcf_result);
    my $cmd2 = Genome::Annotation::Adaptor::SomaticVariation->create(build => $build);
    ok($cmd2->isa('Genome::Annotation::Adaptor::SomaticVariation'), "Command created correctly");
    ok($cmd2->execute, "Command executed successfully");
    cmp_bag([$cmd2->bam_results], [$bam_result1, $bam_result2], "Bam results set as expected");
    is_deeply($cmd2->annotation_build, $build->annotation_build, "Annotation build set as expected");
    is_deeply($cmd2->snv_vcf_result, $snv_vcf_result, "Snvs vcf result set as expected when vcf results are added");
    is_deeply($cmd2->indel_vcf_result, $indel_vcf_result, "Indel vcf result set as expected when vcf results are added");
};

done_testing();

sub setup_objects {
    my $build = Genome::Test::Factory::Model::SomaticVariation->setup_somatic_variation_build;
    my $result1 = Genome::InstrumentData::AlignmentResult::Merged->__define__();
    my $result2 = Genome::InstrumentData::AlignmentResult::Merged->__define__();
    my %build_to_result = (
        $build->tumor_build->id => $result1,
        $build->normal_build->id => $result2,
    );
    reinstall_sub( {
        into => 'Genome::Model::Build::ReferenceAlignment',
        as => 'merged_alignment_result',
        code => sub {my $self = shift;
            return $build_to_result{$self->id};
        },
    });

    my $snv_vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Combine->__define__;
    my $indel_vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Combine->__define__;

    return ($build, $result1, $result2, $snv_vcf_result, $indel_vcf_result);
}

sub add_vcf_results {
    my ($snv_vcf_result, $indel_vcf_result) = @_;
    reinstall_sub({
        into => "Genome::Model::Build::RunsDV2",
        as => "get_detailed_snvs_vcf_result",
        code => sub { my $self = shift;
                      return $snv_vcf_result;
        },
    });
    reinstall_sub({
        into => "Genome::Model::Build::RunsDV2",
        as => "get_detailed_indels_vcf_result",
        code => sub { my $self = shift;
                      return $indel_vcf_result;
        },
    });


}
