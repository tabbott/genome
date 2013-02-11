#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";
use Test::More; 
use File::Compare;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 4;
}

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use_ok( 'Genome::Model::Tools::FastTier::TierVcf');

my $test_data_dir  = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-FastTier-TierVcf';

my $annotation_build_id = 102550711;
my $ab = Genome::Model::Build->get($annotation_build_id);
my $tier_file_location = $ab->tiering_bed_files_by_version(3);

my $vcf_name = "test_out_tiered.vcf.gz";
my $vcf_input = $test_data_dir."/test_out.vcf.gz";
my $expected_file = $test_data_dir . "/expected_v1/".$vcf_name;
my $test_output_dir = File::Temp::tempdir('Genome-Model-Tools-FastTier-TierVcf-XXXXX', CLEANUP => 1, TMPDIR => 1);
my $vcf_output_file = $test_output_dir . "/". $vcf_name;

my $tier_vcf = Genome::Model::Tools::FastTier::TierVcf->create(
    vcf_file => $vcf_input,
    tier_file_location => $tier_file_location,
    vcf_output_file => $vcf_output_file,
);

ok($tier_vcf, 'created TierVcf object');
ok($tier_vcf->execute(), 'executed TierVcf command');

my $vcf_fh = Genome::Sys->open_gzip_file_for_reading($vcf_output_file);
my @lines = <$vcf_fh>;

my $expected_vcf_fh = Genome::Sys->open_gzip_file_for_reading($expected_file);
my @expected_lines = <$expected_vcf_fh>;

my $re = qr(^##source_\d{8}\.1=);
@lines = grep($_ !~ $re, @lines);
@expected_lines = grep($_ !~ $re, @expected_lines);

is_deeply(\@lines, \@expected_lines, "$vcf_output_file output matched expected output");
