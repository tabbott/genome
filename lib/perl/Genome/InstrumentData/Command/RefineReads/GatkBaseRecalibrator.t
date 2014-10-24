#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

# The running logic is tested inside GATK BP
my $class = 'Genome::InstrumentData::Command::RefineReads::GatkBaseRecalibrator';
use_ok($class) or die;
is_deeply([$class->result_names], ['base recalibrator bam'], 'result_names');
ok(!$class->__meta__->property_meta_for_name('known_sites')->is_optional, 'known_sites are not optional');

done_testing();
