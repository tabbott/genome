#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Test::Exception;
use Genome::File::Vcf::Entry;
use Genome::VariantReporting::Suite::BamReadcount::TestHelper qw(
    bam_readcount_line create_entry bam_readcount_line_deletion create_deletion_entry);

my $pkg = 'Genome::VariantReporting::Suite::BamReadcount::VafInterpreter';
use_ok($pkg);
my $factory = Genome::VariantReporting::Framework::Factory->create();
isa_ok($factory->get_class('interpreters', $pkg->name), $pkg);

subtest "one alt allele" => sub {
    my $interpreter = $pkg->create(sample_name => "S1");
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        G => {
            vaf => 1,
            ref_count => 3,
            var_count => 341,
            per_library_var_count => 'Solexa-135852:155,Solexa-135853:186',
            per_library_ref_count => 'Solexa-135852:2,Solexa-135853:1',
            per_library_vaf => 'Solexa-135852:45.0581395348837,Solexa-135853:54.0697674418605',
        }
    );

    my $entry = create_entry(bam_readcount_line);
    cmp_ok({$interpreter->interpret_entry($entry, ['G'])}->{G}->{vaf}, ">", 99, 'vaf is in the desired range');
    cmp_ok({$interpreter->interpret_entry($entry, ['G'])}->{G}->{vaf},  "<", 100, 'vaf is in the desired range');
    is({$interpreter->interpret_entry($entry, ['G'])}->{G}->{ref_count}, $expected{G}->{ref_count}, 'ref count is correct');
    is({$interpreter->interpret_entry($entry, ['G'])}->{G}->{var_count}, $expected{G}->{var_count}, 'var count is correct');
    is({$interpreter->interpret_entry($entry, ['G'])}->{G}->{per_library_var_count}, $expected{G}->{per_library_var_count}, 'per lib var count is correct');
    is({$interpreter->interpret_entry($entry, ['G'])}->{G}->{per_library_ref_count}, $expected{G}->{per_library_ref_count}, 'per lib ref count is correct');
    is({$interpreter->interpret_entry($entry, ['G'])}->{G}->{per_library_vaf}, $expected{G}->{per_library_vaf}, 'per lib vaf is correct');
};

subtest "insertion" => sub {
    my $interpreter = $pkg->create(sample_name => "S4");
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        AA => {
            vaf => 1,
            ref_count => 3,
            var_count => 20,
            per_library_var_count => 'Solexa-135852:20,Solexa-135853:0',
            per_library_ref_count => 'Solexa-135852:2,Solexa-135853:1',
            per_library_vaf => 'Solexa-135852:5.81395348837209,Solexa-135853:0',
        }
    );

    my $entry = create_entry(bam_readcount_line);
    cmp_ok({$interpreter->interpret_entry($entry, ['AA'])}->{AA}->{vaf}, ">", 5, 'vaf is in the desired range');
    cmp_ok({$interpreter->interpret_entry($entry, ['AA'])}->{AA}->{vaf},  "<", 6, 'vaf is in the desired range');
    is({$interpreter->interpret_entry($entry, ['AA'])}->{AA}->{ref_count}, $expected{AA}->{ref_count}, 'ref count is correct');
    is({$interpreter->interpret_entry($entry, ['AA'])}->{AA}->{var_count}, $expected{AA}->{var_count}, 'var count is correct');
    is({$interpreter->interpret_entry($entry, ['AA'])}->{AA}->{per_library_var_count}, $expected{AA}->{per_library_var_count}, 'per lib var count is correct');
    is({$interpreter->interpret_entry($entry, ['AA'])}->{AA}->{per_library_ref_count}, $expected{AA}->{per_library_ref_count}, 'per lib ref count is correct');
    is({$interpreter->interpret_entry($entry, ['AA'])}->{AA}->{per_library_vaf}, $expected{AA}->{per_library_vaf}, 'per lib vaf is correct');
};

subtest "deletion" => sub {
    my $interpreter = $pkg->create(sample_name => "S1");
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        A => {
            vaf => 1,
            ref_count => 5,
            var_count => 20,
            per_library_var_count => 'Solexa-135852:20,Solexa-135853:0',
            per_library_ref_count => 'Solexa-135852:3,Solexa-135853:2',
            per_library_vaf => 'Solexa-135852:5.81395348837209,Solexa-135853:0',
        }
    );

    my $entry = create_deletion_entry(bam_readcount_line_deletion);
    cmp_ok({$interpreter->interpret_entry($entry, ['A'])}->{A}->{vaf}, ">", 5, 'vaf is in the desired range');
    cmp_ok({$interpreter->interpret_entry($entry, ['A'])}->{A}->{vaf},  "<", 6, 'vaf is in the desired range');
    is({$interpreter->interpret_entry($entry, ['A'])}->{A}->{ref_count}, $expected{A}->{ref_count}, 'ref count is correct');
    is({$interpreter->interpret_entry($entry, ['A'])}->{A}->{var_count}, $expected{A}->{var_count}, 'var count is correct');
    is({$interpreter->interpret_entry($entry, ['A'])}->{A}->{per_library_var_count}, $expected{A}->{per_library_var_count}, 'per lib var count is correct');
    is({$interpreter->interpret_entry($entry, ['A'])}->{A}->{per_library_ref_count}, $expected{A}->{per_library_ref_count}, 'per lib ref count is correct');
    is({$interpreter->interpret_entry($entry, ['A'])}->{A}->{per_library_vaf}, $expected{A}->{per_library_vaf}, 'per lib vaf is correct');
};
done_testing;

