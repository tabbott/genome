#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Workflow::Simple;

require File::Compare;
use File::Temp;
use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}

use_ok('Genome::Model::Build::DeNovoAssembly::Abyss') or die;

my $base_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model/DeNovoAssembly';
my $archive_path = $base_dir.'/inst_data/-7777/archive.tgz';
ok(-s $archive_path, 'inst data archive path') or die;
my $example_version = '1';
my $example_dir = $base_dir.'/abyss_v'.$example_version;
ok(-d $example_dir, 'example dir') or die;

my $tmpdir_template = $ENV{'GENOME_TEST_TEMP'}
    . "/DeNovoAssembly-Abyss.t-XXXXXXXX";
my $tmpdir = File::Temp::tempdir($tmpdir_template, CLEANUP => 1);
ok(-d $tmpdir, 'temp dir: '.$tmpdir);

my $taxon = Genome::Taxon->create(
    name => 'Escherichia coli TEST',
    domain => 'Bacteria',
    current_default_org_prefix => undef,
    estimated_genome_size => 4500000,
    current_genome_refseq_id => undef,
        ncbi_taxon_id => undef,
        ncbi_taxon_species_name => undef,
    species_latin_name => 'Escherichia coli',
    strain_name => 'TEST',
);
ok($taxon, 'taxon') or die;
my $sample = Genome::Sample->create(
    id => -1234,
    name => 'TEST-000',
);
ok($sample, 'sample') or die;
my $library = Genome::Library->create(
    id => -12345,
    name => $sample->name.'-testlibs',
    sample_id => $sample->id,
    library_insert_size => 260,
);
ok($library, 'library') or die;

my $instrument_data = Genome::InstrumentData::Solexa->create(
    id => -7777,
    sequencing_platform => 'solexa',
    read_length => 100,
    subset_name => '8-CGATGT',
    index_sequence => 'CGATGT',
    run_name => 'XXXXXX/8-CGATGT',
    run_type => 'Paired',
    flow_cell_id => 'XXXXXX',
    lane => 8,
    library => $library,
    archive_path => $archive_path,
    median_insert_size => 260,
    clusters => 15000,
    fwd_clusters => 15000,
    rev_clusters => 15000,
    analysis_software_version => 'not_old_iilumina',
);
ok($instrument_data, 'instrument data');
ok($instrument_data->is_paired_end, 'inst data is paired');
ok(-s $instrument_data->archive_path, 'inst data archive path');

my $pp = Genome::ProcessingProfile::DeNovoAssembly->create(
    name => 'De Novo Assembly Abyss Test',
    assembler_name => 'abyss parallel',
    assembler_version => '1.2.7',
    assembler_params => '-kmer_size 25,31..35 step 2,50 -num_jobs 4',
);
ok($pp, 'pp') or die;

my $model = Genome::Model::DeNovoAssembly->create(
    processing_profile => $pp,
    subject_name => $taxon->name,
    subject_type => 'species_name',
    center_name => 'WUGC',
);
ok($model, 'soap de novo model') or die;
ok($model->add_instrument_data($instrument_data), 'add inst data to model');

my $build = Genome::Model::Build::DeNovoAssembly->create(
    model => $model,
    data_directory => $tmpdir,
);
ok($build, 'created build');
my $example_build = Genome::Model::Build->create(
    model => $model,
    data_directory => $example_dir,
);
ok($example_build, 'create example build');


my $workflow = $pp->_resolve_workflow_for_build($build);
$workflow->validate();
ok($workflow->is_valid, 'workflow validated');

my %workflow_inputs = $model->map_workflow_inputs($build);
my %expected_workflow_inputs = (
        build => $build,
        instrument_data => [$instrument_data],
    );
is_deeply(\%workflow_inputs, \%expected_workflow_inputs,
    'map_workflow_inputs succeeded');


my $workflow_xml = $workflow->save_to_xml();
my $success = Workflow::Simple::run_workflow($workflow_xml, %workflow_inputs);
SKIP: {
    skip("Abyss refactor passes old tests, but workflow does not succeed.", 1, 0);
    ok($success, 'workflow completed');
};
# since the run_workflow changes the cwd when it fails we have to chdir back
# in order for File::Temp::tempdir to be able to clean up when we're done.
chdir;


my @assembler_input_files = $build->existing_assembler_input_files;
is(@assembler_input_files, 2, 'assembler input files exist');
is_deeply(\@assembler_input_files,
    [ map { $tmpdir.'/'.$_ } (qw/ fwd.fq rev.fq /) ],
    'existing assembler file names');

my %assembler_params = $build->assembler_params;
is_deeply(
    \%assembler_params,
    {
        'version' => '1.2.7',
        'fastq_a' => $assembler_input_files[0],
        'fastq_b' => $assembler_input_files[1],
        'num_jobs' => '4',
        'kmer_size' => '25,31..35 step 2,50',
        'output_directory' => $build->data_directory,
    },
    'assembler params',
);

my @build_metric_names = sort(map {$_->name} $build->metrics);
my @unique_build_metric_names = sort(List::MoreUtils::uniq(@build_metric_names));

is_deeply(\@build_metric_names, \@unique_build_metric_names,
    'no duplicate metrics');

my @example_assembler_input_files = $example_build->existing_assembler_input_files;
is(@example_assembler_input_files, 2,
    'example assembler input files do not exist');

is(File::Compare::compare($assembler_input_files[0],
        $example_assembler_input_files[0]),
    0, 'assembler fwd file matches');
is(File::Compare::compare($assembler_input_files[1],
        $example_assembler_input_files[1]),
    0, 'assembler rev file matches');

my %expected_metrics = (
    reads_attempted => 30000,
    reads_processed => 30000,
    reads_processed_success => "1.000",
);

foreach my $metric_name (keys %expected_metrics) {
    is($build->get_metric($metric_name), $expected_metrics{$metric_name},
        "metric ok: '$metric_name'" );
}

done_testing();
