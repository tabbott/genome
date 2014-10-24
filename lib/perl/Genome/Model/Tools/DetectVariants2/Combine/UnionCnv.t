#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
};

use_ok('Genome::Model::Tools::DetectVariants2::Combine::UnionCnv');

my $test_data_dir  = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-DetectVariants2-Combine-UnionCnv';
is(-d $test_data_dir, 1, 'test_data_dir exists') || die;

# FIXME This directory had snvs in it so I copied results to detect future differences.
# 7e05db4b32643b25934ae51b35f1c01e  cnv_input_a/cnvs.hq
# d41d8cd98f00b204e9800998ecf8427e  cnv_input_b/cnvs.hq # this is an empty file!
my $expected_output = $test_data_dir."/expected";
is(-d $expected_output, 1, 'expected_output exists') || die;

# FIXME Swap this for a test constructed reference build.
my $reference_build = Genome::Model::Build->get(101947881);
ok($reference_build, 'got reference_build');

my $aligned_reads         = join('/', $test_data_dir, 'flank_tumor_sorted.bam');
my $control_aligned_reads = join('/', $test_data_dir, 'flank_normal_sorted.bam');

my $detector_name_a = 'Genome::Model::Tools::DetectVariants2::PlotCnv';
my $detector_version_a = 'awesome';
my $output_dir_a = join('/', $test_data_dir, 'cnv_input_a');
my $detector_a = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir            => $output_dir_a,
    reference_build       => $reference_build,
    detector_name         => $detector_name_a,
    detector_version      => $detector_version_a,
    detector_params       => '',
    aligned_reads         => $aligned_reads,
    control_aligned_reads => $control_aligned_reads,
);
$detector_a->lookup_hash($detector_a->calculate_lookup_hash());
isa_ok($detector_a, 'Genome::Model::Tools::DetectVariants2::Result', 'detector_a');

my $detector_name_b    = 'Genome::Model::Tools::DetectVariants2::PlotCnv';
my $detector_version_b = 'awesome';
my $output_dir_b = join('/', $test_data_dir, 'cnv_input_b');
my $detector_b = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir            => $output_dir_b,
    reference_build       => $reference_build,
    detector_name         => $detector_name_b,
    detector_version      => $detector_version_b,
    detector_params       => '',
    aligned_reads         => $aligned_reads,
    control_aligned_reads => $control_aligned_reads,
);
$detector_b->lookup_hash($detector_b->calculate_lookup_hash());
isa_ok($detector_b, 'Genome::Model::Tools::DetectVariants2::Result', 'detector_b');

my $test_output_dir = File::Temp::tempdir('Genome-Model-Tools-DetectVariants2-Combine-UnionCnv-XXXXX', CLEANUP => 1, TMPDIR => 1);
my $output_symlink  = join('/', $test_output_dir, 'union-cnv');
my $union_cnv_object = Genome::Model::Tools::DetectVariants2::Combine::UnionCnv->create(
    input_a_id           => $detector_a->id,
    input_b_id           => $detector_b->id,
    output_directory     => $output_symlink,
    aligned_reads_sample => 'TEST',
);
ok($union_cnv_object, 'created UnionCnv object');
ok($union_cnv_object->execute(), 'executed UnionCnv object');

my @files = qw| cnvs.hq |;

for my $file (@files) {
    my $test_output = $output_symlink."/".$file;
    my $expected_output = $expected_output."/".$file;
    is(compare($test_output,$expected_output),0, "Found no difference between test output: ".$test_output." and expected output:".$expected_output);
}

done_testing();
