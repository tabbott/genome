#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use above 'Genome';
use Sub::Override qw();

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

my $pkg = 'Genome::Command::DelegatesToResult';
use_ok($pkg) || die;

{
    package TestCommand;

    use strict;
    use warnings FATAL => 'all';
    use Genome;

    class TestCommand {
        is => [$pkg],
        has => [
            test_name => {},
        ],
    };

    sub result_class {
        return "TestResult";
    }

    sub input_hash {
        my $self = shift;
        return (test_name => $self->test_name);
    }
}
{
    package TestResult;

    use strict;
    use warnings FATAL => 'all';
    use Genome;

    class TestResult {
        is => 'Genome::SoftwareResult',
    };
}
{
    package TestUser;

    use strict;
    use warnings FATAL => 'all';
    use Genome;

    class TestUser {
        is => 'UR::Object',
        has => [
            name => {},
        ],
    };
}

my $USER1 = TestUser->create(name => 'USER1');

my $cmd = TestCommand->create(user => $USER1, test_name => 'foo');
is($cmd->shortcut(), 0, 'Shortcut returns 0 when no result exists') or die;
is($cmd->execute(), 1, 'Execute returns 1 when successful') or die;

my $sr = $cmd->output_result;
ok($sr, 'Found a TestResult was created') or die;

check_sr_user($sr, $USER1, 'created');


my $USER2 = TestUser->create(name => 'USER2');
$cmd = TestCommand->create(user => $USER2, test_name => 'foo');
is($cmd->shortcut(), 1, 'Shortcut returns 1 when result exists') or die;

my $shortcut_sr = $cmd->output_result;
is($shortcut_sr, $sr, 'Found the same TestResult when shortcutting') or die;

check_sr_user($sr, $USER2, 'shortcut');

$cmd = TestCommand->create(user => $USER2, label => "label2", test_name => 'baz');
$cmd->execute();
check_sr_user($cmd->output_result, $USER2, 'label2');
check_sr_user($cmd->output_result, $USER2, 'created');

$cmd = TestCommand->create(test_name => 'bar');
$cmd->execute();
is_deeply([$cmd->output_result->users], [], "No users created when 'user' is not passed as an input");

subtest 'exception_safety' => sub {
    my $cmd = TestCommand->create(test_name => 'exception_safe');
    my $override = Sub::Override->new(
        'Genome::Command::DelegatesToResult::_fetch_result' => sub {die 'test'});

    is($cmd->shortcut(), undef, 'shortcut returns undef instead of dying');
    my $error_message = $cmd->error_message();
    like($error_message, qr/Exception in shortcut: test/, 'Found appropriate error message for shortcut failure');

    is($cmd->execute(), undef, 'execute returns undef instead of dying');
    $error_message = $cmd->error_message();
    like($error_message, qr/Exception in execute: test/, 'Found appropriate error message for execute failure');

    $override->restore();
};

done_testing();

sub check_sr_user {
    my $sr = shift;
    my $user = shift;
    my $label = shift;

    subtest sprintf("SoftwareResult::User (%s)", $user->name) => sub {
        my $sr_user = Genome::SoftwareResult::User->get(
            user => $user,
            software_result => $sr,
            label => $label);
        ok($sr_user, 'Found a SoftwareResult::User was created') or die;
    };
}
