#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
};

use above 'Genome';

use Data::Dumper;
require File::Temp;
require File::Compare;
use Test::More;

use_ok('Genome::Model::GenotypeMicroarray::GenotypeFile::ReaderFactory') or die;
use_ok('Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory') or die;
use_ok('Genome::Model::GenotypeMicroarray::Test') or die;

my $testdir = Genome::Model::GenotypeMicroarray::Test::testdir();
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

my $example_legacy_build = Genome::Model::GenotypeMicroarray::Test::example_legacy_build();
my $example_build = Genome::Model::GenotypeMicroarray::Test::example_build();

###
# TSV [inst data] to TSV [original genotype file]
my $reader = Genome::Model::GenotypeMicroarray::GenotypeFile::ReaderFactory->build_reader(
    source => Genome::Model::GenotypeMicroarray::Test::instrument_data(),
    variation_list_build => Genome::Model::GenotypeMicroarray::Test::variation_list_build(),
);
ok($reader, 'build reader');
my $output_tsv = $tmpdir.'/genotypes.tsv';
my $writer = Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory->build_writer(
    header => $reader->header,
    string => $output_tsv,
);
ok($writer, 'create writer');

my @genotypes_from_instdata;
while ( my $genotype = $reader->read ) {
    $writer->write($genotype);
}
$writer->output->flush;
is(File::Compare::compare($output_tsv, $example_build->original_genotype_file_path), 0, 'read tsv and annotate, write to tsv output file matches');
#print "gvimdiff $output_tsv ".$example_build->original_genotype_file_path."\n"; <STDIN>;

###
# TSV [legacy build] to VCF [new build]
$reader = Genome::Model::GenotypeMicroarray::GenotypeFile::ReaderFactory->build_reader(source => $example_legacy_build);
ok($reader, 'create reader');

my $output_vcf = $tmpdir.'/genotypes.vcf';
$writer = Genome::Model::GenotypeMicroarray::GenotypeFile::WriterFactory->build_writer(
    header => $reader->header,
    string => $output_vcf,
);
ok($writer, 'create writer');

my @genotypes_from_legacy_build;
while ( my $genotype = $reader->read ) {
    $writer->write($genotype);
}
$writer->close;
is(File::Compare::compare($output_vcf, $example_build->original_genotype_vcf_file_path), 0, 'read tsv, write to vcf output file matches');
#print "gvimdiff $output_vcf ".$example_build->original_genotype_vcf_file_path."\n"; <STDIN>;

done_testing();
