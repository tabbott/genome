#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use above "Genome";
use Test::More;

use_ok('Genome::Model::ClinSeq::Command::GenerateSciclonePlots') or die;
 
#Define the test where expected results are stored
my $expected_output_dir = $ENV{"GENOME_TEST_INPUTS"} .
  "Genome-Model-ClinSeq-Command-GenerateSciclonePlots/2014-11-13/";
ok(-e $expected_output_dir, "Found test dir: $expected_output_dir") or die;

my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir") or die;

#Run GenerateSciclone on the 'apipe-test-clinseq-wer' model
my $clinseq_build =
  Genome::Model::Build->get(id => '35af836fbcd243c59c44825af7e3983b');
ok($clinseq_build, "Found clinseq build.");
my $run_sciclone = Genome::Model::ClinSeq::Command::GenerateSciclonePlots->create(
  outdir => $temp_dir,
  clinseq_build => $clinseq_build,
  test => 1,
);
$run_sciclone->queue_status_messages(1);
$run_sciclone->execute();

#Dump the output to a log file
my @output1 = $run_sciclone->status_messages();
my $log_file = $temp_dir . "/GenerateSciclonePlots.log.txt";
my $log = IO::File->new(">$log_file");
$log->print(join("\n", @output1));
$log->close();
ok(-e $log_file, "Wrote message file from generate-sciclone-plots to a log
     file: $log_file");

my $format_clusters_command = "cut -f 1-10 $temp_dir/sciclone.tumor_exome_day0.clusters.txt > $temp_dir/sciclone.H_KA-763312-1224733_exome_tumor_day0.clusters.txt.formatted";
Genome::Sys->shellcmd(cmd => $format_clusters_command);

my @diff = `diff -r -x '*.log.txt' -x '*.pdf' -x '*.jpeg' -x '*clusters.txt' -x '*R' $expected_output_dir $temp_dir`;
ok(@diff == 0, "Found only expected number of differences between expected
  results and test results")
or do {
  diag("expected: $expected_output_dir\nactual: $temp_dir\n");
  diag("differences are:");
  diag(@diff);
  my $diff_line_count = scalar(@diff);
  Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-run-generatescicloneplots/");
  Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-run-generatescicloneplots");
  die print "\n\nFound $diff_line_count differing lines\n\n";
};

done_testing();
