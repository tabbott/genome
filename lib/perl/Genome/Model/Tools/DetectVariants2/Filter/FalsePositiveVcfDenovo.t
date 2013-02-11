#!/usr/bin/env genome-perl

BEGIN {
    $ENV{NO_LSF} = 1;     
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 22;
}

use_ok('Genome::Model::Tools::DetectVariants2::Filter::FalsePositiveVcfDenovo');

my $test_data_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-DetectVariants2-Filter-FalsePositiveVcfDenovo';

# FIXME currently snvs.vcf.gz has been copied into the detector dir even though that is a lie.

my $detector_directory = join('/', $test_data_dir, 'polymutt-0.02');
my $input_vcf = join('/', $detector_directory, 'snvs.vcf.gz');
# V2 makes DNFT a per-sample value rather than INFO
my $expected_dir = join('/', $test_data_dir, 'expected.v2');
my $expected_vcf_file = join('/', $expected_dir, 'snvs.vcf.gz');
my $expected_header = join('/', $expected_dir, 'header.vcf');
my $expected_header_with_filter = join('/', $expected_dir, 'header_plus_filters.vcf');
my $expected_regions = join('/', $expected_dir, 'regions');
#ok(-s $expected_vcf_file, "expected output $expected_vcf_file exists");

my $outter_output_dir = File::Temp::tempdir('DetectVariants2-Filter-FalsePositiveVcfDenovoXXXXX', CLEANUP => 1, TMPDIR => 1);
my $output_dir = File::Temp::tempdir('DetectVariants2-Filter-FalsePositiveVcfDenovoXXXXX', DIR => $outter_output_dir, CLEANUP => 1);
#my $output_dir = File::Temp::tempdir('DetectVariants2-Filter-FalsePositiveVcfDenovoXXXXX', DIR => '/tmp/', CLEANUP => 0);

my $output_vcf = join('/', $output_dir, 'snvs.vcf.gz');
my $output_regions = join('/', $output_dir, 'regions');


# TODO This test should define alignment results rather than relying on existing ones
my @test_alignment_result_ids = qw(116541600 116542878 116545029);
my @test_alignment_results = Genome::InstrumentData::AlignmentResult::Merged->get(\@test_alignment_result_ids);
is(scalar(@test_alignment_results), 3, "Got 3 test alignment results");

my $detector_result = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir => $detector_directory,
    detector_name => 'Genome::Model::Tools::DetectVariants2::Polymutt',
    detector_params => '',
    detector_version => 'awesome',
    reference_build_id => 101947881,
);
$detector_result->lookup_hash($detector_result->calculate_lookup_hash());

my $i = 0;
for my $result (@test_alignment_results) {
    $detector_result->add_input(
        name => "alignment_results-$i",
        value_id => $result->id,
        value_class_name => $result->class
    );
    ++$i;
}

my $result_allocation = Genome::Disk::Allocation->create(
    disk_group_name => 'info_genome_models',
    kilobytes_requested => 1,
    allocation_path => 'this_is_a_test',
    owner_id => $detector_result->id,
    owner_class_name => $detector_result->class,
);

my $filter_command = Genome::Model::Tools::DetectVariants2::Filter::FalsePositiveVcfDenovo->create(
    previous_result_id => $detector_result->id,
    output_directory => $output_dir,
    bam_readcount_version => 0.3,
);
$filter_command->dump_status_messages(1);
isa_ok($filter_command, 'Genome::Model::Tools::DetectVariants2::Filter::FalsePositiveVcfDenovo', 'created filter command');

# Test individual methods
my ($input_fh, $header) = $filter_command->parse_vcf_header($input_vcf);
my $header_diff = Genome::Sys->diff_file_vs_text($expected_header, join("", @$header) );
ok(!$header_diff, 'parsed header matches expected result')
    or diag("diff:\n" . $header_diff);

my @expected_samples = qw(H_ME-DS10239_2-DS10239_2 H_ME-DS10239_3-DS10239_3 H_ME-DS10239_1-DS10239_1);
my @samples = $filter_command->get_samples_from_header($header);
#is_deeply(\@samples, \@expected_samples, "Got the expected samples from get_samples_from_header");

my $return = $filter_command->print_region_list($input_vcf, $output_regions);
my $region_diff = Genome::Sys->diff_file_vs_file($output_regions, $expected_regions);
ok(!$header_diff, 'regions file matches expected result')
    or diag("diff:\n" . $header_diff);

# FIXME this should be moved to another test case entirely, testing the base vcf methods
my $test_vcf_line = "1	121352388	.	T	C	77	PolymuttDenovo	NS=3;PS=100.0;TEST;DP=152;DQ=2.181	GT:GQ:DP:GL	C/C:41:38:221,83,130,215,42,0,80,115,130,226	C/C:21:52:255,149,173,228,83,0,101,86,124,225	C/G:22:62:255,162,203,243,105,0,95,80,132,237";
my $parsed_line = $filter_command->parse_vcf_line($test_vcf_line, \@samples);
#ok($parsed_line, "Got a parsed line from parse_vcf_line");

# Set up the expected data structure
my $expected_line;
$expected_line->{chromosome} = 1;
$expected_line->{position} = 121352388;
$expected_line->{id} = ".";
$expected_line->{reference} = "T";
$expected_line->{alt} = "C";
$expected_line->{qual} = 77;
$expected_line->{filter} = "PolymuttDenovo";
$expected_line->{'_info_tags'} = [ qw{ NS PS TEST DP DQ } ];
$expected_line->{'_format_fields'} = [ qw{ GT GQ DP GL } ];
my $expected_info;
$expected_info->{NS} = 3;
$expected_info->{PS} = "100.0";
$expected_info->{DP} = 152;
$expected_info->{DQ} = 2.181;
$expected_info->{TEST} = undef;
my ($sample1,$sample2,$sample3);
$sample1->{GT} = "C/G";
$sample1->{GQ} = 22;
$sample1->{DP} = 62;
$sample1->{GL} = "255,162,203,243,105,0,95,80,132,237";
$sample2->{GT} = "C/C";
$sample2->{GQ} = 41;
$sample2->{DP} = 38;
$sample2->{GL} = "221,83,130,215,42,0,80,115,130,226";
$sample3->{GT} = "C/C";
$sample3->{GQ} = 21;
$sample3->{DP} = 52;
$sample3->{GL} = "255,149,173,228,83,0,101,86,124,225";
#my @expected_sample = ($sample1,$sample2,$sample1);
#$expected_line->{sample} = \@expected_sample;
$expected_line->{sample}->{"H_ME-DS10239_1-DS10239_1"} = $sample1;
$expected_line->{sample}->{"H_ME-DS10239_2-DS10239_2"} = $sample2;
$expected_line->{sample}->{"H_ME-DS10239_3-DS10239_3"} = $sample3;
$expected_line->{info} = $expected_info;

# Check for the expected data structure
is_deeply($parsed_line, $expected_line, "Parsed vcf line data structure matches expectations");

# reconstruct the line with deparse
is($filter_command->deparse_vcf_line($parsed_line,\@expected_samples),"$test_vcf_line\n", "Deparsed vcf line data structure matches input line");


my $variant1 = $filter_command->get_variant_for_sample($parsed_line->{"alt"}, $parsed_line->{sample}->{"H_ME-DS10239_1-DS10239_1"}->{GT}, $parsed_line->{"reference"}, );
is($variant1, "C", "get_variant_for_sample works for sample 1");
my $variant2 = $filter_command->get_variant_for_sample($parsed_line->{"alt"}, $parsed_line->{sample}->{"H_ME-DS10239_2-DS10239_2"}->{GT}, $parsed_line->{"reference"});
is($variant2, "C", "get_variant_for_sample works for sample 2");
my $variant3 = $filter_command->get_variant_for_sample($parsed_line->{"alt"}, $parsed_line->{sample}->{"H_ME-DS10239_3-DS10239_3"}->{GT}, $parsed_line->{"reference"});
is($variant3, "C", "get_variant_for_sample works for sample 3");

# Check fabricated cases to make sure this works in crazier cases... (ALT, GT, REF)
my $variant4 = $filter_command->get_variant_for_sample("C,A,G", "A/G", "T");
is($variant4, "A", "get_variant_for_sample works for fabricated sample 1");

my $variant5 = $filter_command->get_variant_for_sample("C,A,G", "G/A", "T");
is($variant5, "A", "get_variant_for_sample works for fabricated sample 2");

my $variant6 = $filter_command->get_variant_for_sample("T,A,G", "T/C", "C");
is($variant6, "T", "get_variant_for_sample works for fabricated sample 3");

my @test_alleles = qw(T C A G);
my $expected_allele = "A";
my $prioritized_allele = $filter_command->prioritize_allele(\@test_alleles);
is($prioritized_allele, $expected_allele, "prioritize_allele returns the expected value");

my $pass_test_sample = "H_ME-DS10239_1-DS10239_1";
isnt($expected_line->{sample}->{$pass_test_sample}->{DNFT}, "PASS", "No FT field set previously, as expected");
my $filter_pass_line = $filter_command->pass_sample($expected_line, $pass_test_sample);
is($expected_line->{sample}->{$pass_test_sample}->{DNFT}, "PASS", "FT field is now PASS as expected");

#my $filter_name = "FPTF";
#my $fail_test_sample = "H_ME-DS10239_2-DS10239_2";
#isnt($expected_line->{sample}->{$fail_test_sample}->{FT}, $filter_name, "No FT field set previously, as expected");
#my $filter_fail_line = $filter_command->fail_sample($expected_line, $fail_test_sample,$filter_name);
#is($expected_line->{sample}->{$fail_test_sample}->{FT}, $filter_name, "FT field is now $filter_name as expected");
#second filter test
#my $filter_name2 = "FPTF2";
#$filter_fail_line = $filter_command->fail_sample($expected_line, $fail_test_sample,$filter_name2);
#is($expected_line->{sample}->{$fail_test_sample}->{FT}, "$filter_name;$filter_name2", "FT field is now $filter_name;$filter_name2 as expected");


#failing a previously passed sample
#my $filter_fail_line3 = $filter_command->fail_sample($expected_line, $pass_test_sample,$filter_name);
#is($expected_line->{sample}->{$pass_test_sample}->{FT}, $filter_name, "Previously passed FT field is now $filter_name as expected");

#test filter setting


my @test_alt = qw(C T);
my $test_reference = "A";
my @test_gt = qw(0 1);
my @alleles = $filter_command->convert_numeric_gt_to_alleles(\@test_alt, \@test_gt, $test_reference);
my @expected_alleles = qw(A C);
is_deeply(\@alleles, \@expected_alleles, "convert_numeric_gt_to_alleles works as expected for GT ". join("/", @test_gt));

@expected_alleles = qw(C);
@test_gt = qw(1 1);
@alleles = $filter_command->convert_numeric_gt_to_alleles(\@test_alt, \@test_gt, $test_reference);
is_deeply(\@alleles, \@expected_alleles, "convert_numeric_gt_to_alleles works as expected for GT ". join("/", @test_gt));

@expected_alleles = qw(T);
@test_gt = qw(2 2);
@alleles = $filter_command->convert_numeric_gt_to_alleles(\@test_alt, \@test_gt, $test_reference);
is_deeply(\@alleles, \@expected_alleles, "convert_numeric_gt_to_alleles works as expected for GT ". join("/", @test_gt));

# TODO Methods that still need to be tested:
# $filter_command->filter_one_line
# $filter_command->filter_one_sample


ok($filter_command->execute(), 'executed filter command');

ok(-s $output_vcf, "output vcf exists and has size"); 
$DB::single=1;
my $expected_text = `zcat $expected_vcf_file | grep -v '^##fileDate'`;
my $test_text = `zcat $output_vcf | grep -v '^##fileDate'`;

my $output_diff = Genome::Sys->diff_text_vs_text($expected_text, $test_text);
ok(!$output_diff, 'output file matches expected result')
    or diag("diff:\n" . $output_diff);
done_testing();
