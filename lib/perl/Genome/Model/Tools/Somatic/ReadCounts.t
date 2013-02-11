#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    } else {
        plan tests => 5;
    }

    use_ok('Genome::Model::Tools::Somatic::ReadCounts');    
};

my $test_input_dir          = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-Somatic-ReadCounts/';
my $tumor_bam               = $test_input_dir . 'tumor.tiny.bam';
my $normal_bam              = $test_input_dir . 'normal.tiny.bam';
my $sites_file              = $test_input_dir . 'sites.in';

my $test_output_dir         = File::Temp::tempdir('Genome-Model-Tools-Somatic-ReadCounts-XXXXX', CLEANUP => 1, TMPDIR => 1);
$test_output_dir .= '/';
my $output_file             = $test_output_dir . 'readcounts.out';

my $expected_dir            = $test_input_dir;
my $expected_output_file    = $expected_dir . 'readcounts.expected';

my $read_counts = Genome::Model::Tools::Somatic::ReadCounts->create(
    tumor_bam   => $tumor_bam,
    normal_bam  => $normal_bam,
    sites_file  => $sites_file,
    output_file => $output_file,
    minimum_mapping_quality => 30,
);

ok($read_counts, 'created ReadCounts object');
ok($read_counts->execute(), 'executed ReadCounts object');

ok(-s $output_file, 'generated output file');
is(compare($output_file, $expected_output_file), 0, 'output file matched expected results');
