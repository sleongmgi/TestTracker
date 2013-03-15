use strict;
use warnings;

use Cwd qw(cwd realpath);
use File::Basename qw(dirname);

my $lib_dir;
BEGIN {
    $lib_dir  = realpath(dirname(__FILE__) . '/../../lib');
}

use lib $lib_dir;

my $bin_dir  = realpath(dirname(__FILE__) . '/../../bin');
$ENV{PERL5LIB} = join(':', $lib_dir, $ENV{PERL5LIB});
$ENV{PATH} = join(':', $bin_dir, $ENV{PATH});

use File::Spec qw();
use Test::More;
use IPC::System::Simple qw(capture);
use Test::System import => [qw(run_ok)];
use Test::TestTracker import => [qw(
    db_filename
    conf_filename
    create_a_repo
    create_a_config
    create_a_database
)];
use TestTracker;
use File::Temp qw();

my $orig_cwd = cwd();

is($INC{'TestTracker.pm'}, File::Spec->join($lib_dir, 'TestTracker.pm'),
    "found correct TestTracker.pm");

my $tt_path = capture('which', 'test-tracker');
chomp $tt_path;
is($tt_path, File::Spec->join($bin_dir, 'test-tracker'),
    "found correct test-tracker bin");

my $test_dir = File::Temp->newdir(TMPDIR => 1);
my $git_dir = create_a_repo($test_dir);
chdir $git_dir;

my $db_filename = db_filename();
my $conf_filename = conf_filename();

my %config = create_a_config();
run_ok(['git', 'add', $conf_filename]);
run_ok(['git', 'commit', '-m ""', $conf_filename]);

my %test_db = create_a_database();
run_ok(['git', 'add', $db_filename]);
run_ok(['git', 'commit', '-m ""', $db_filename]);

my @test_filenames = keys %test_db;
ok(@test_filenames > 0, 'test database has tracked tests');

run_ok(['git', 'tag', '-a', '-m', '', 'start'], 'tagged repo as "start"');

{ # detect changes to tracked test
    run_ok(['git', 'reset', '--hard', 'start']);
    run_ok(['git', 'clean', '-xdf']);

    my $tt_filename = $test_filenames[0];
    run_ok(['touch', $tt_filename]);
    my @found_ut_capture = capture('test-tracker', 'list', '--git');
    my $found_ut = grep { $_ =~ /^\s+\d+\s+$tt_filename$/ } @found_ut_capture;
    ok($found_ut, "found uncommitted, tracked test file: '$tt_filename'")
        or diag(join("\n", @found_ut_capture));

    run_ok(['git', 'add', $tt_filename]);
    run_ok(['git', 'commit', '-m ""', $tt_filename]);
    run_ok(['git', 'clean', '-xdf']);
    my @found_ct_capture = capture('test-tracker', 'list', '--git');
    my $found_ct = grep { $_ =~ /^\s+\d+\s+$tt_filename$/ } @found_ct_capture;
    ok($found_ct, "found committed, tracked test file: '$tt_filename'")
        or diag(join("\n", @found_ct_capture));
}

{ # detect untracked test
    run_ok(['git', 'reset', '--hard', 'start']);
    run_ok(['git', 'clean', '-xdf']);

    my $tu_filename = 'untracked.t';
    ok((!grep { $_ eq $tu_filename } @test_filenames), 'verified untracked test file is not in test database');
    run_ok(['touch', $tu_filename]);
    my @found_uu_capture = capture('test-tracker', 'list', '--git');
    my $found_uu = grep { $_ =~ /^\s+\d+\s+$tu_filename$/ } @found_uu_capture;
    ok($found_uu, "found uncommitted, untracked test file: '$tu_filename'")
        or diag(join("\n", @found_uu_capture));

    run_ok(['git', 'add', $tu_filename]);
    run_ok(['git', 'commit', '-m ""', $tu_filename]);
    run_ok(['git', 'clean', '-xdf']);
    my @found_cu_capture = capture('test-tracker', 'list', '--git');
    my $found_cu = grep { $_ =~ /^\s+\d+\s+$tu_filename$/ } @found_cu_capture;
    ok($found_cu, "found committed, untracked test file: '$tu_filename'")
        or diag(join("\n", @found_cu_capture));
}

{ # detects renamed test
    run_ok(['git', 'reset', '--hard', 'start']);
    run_ok(['git', 'clean', '-xdf']);

    my $filename = $test_filenames[0];
    run_ok(['touch', $filename]);
    run_ok(['git', 'add', $filename]);
    run_ok(['git', 'commit', '-m ""', $filename]);

    my $new_filename = 'untracked.t';
    run_ok(['git', 'mv', $filename, $new_filename]);

    my @list = capture('test-tracker', 'list', '--git');
    my @tests = map { (/^\s+\d+\s+(.*)/)[0] } @list;

    my $found_renamed_test = grep { /^$new_filename$/ } @tests;
    ok($found_renamed_test, 'found renamed test') or diag @list;
    my $found_previous_test = grep { /^$filename$/ } @tests;
    ok(!$found_previous_test, 'did not find previous test') or diag @list;
}

{ # detect same tests after module rename
    run_ok(['git', 'reset', '--hard', 'start']);
    run_ok(['git', 'clean', '-xdf']);

    my $test_filename = $test_filenames[0];

    my @list_a = capture('test-tracker', 'list', '--git');
    my @tests_a = map { (/^\s+\d+\s+(.*)/)[0] } @list_a;
    my $found_test_a = grep { /^$test_filename$/ } @tests_a;
    ok(!$found_test_a, 'did not find test before module changed/created');

    my $module_filename = $test_db{$test_filename}->[0];
    run_ok(['touch', $module_filename]);
    run_ok(['git', 'add', $module_filename]);
    run_ok(['git', 'commit', '-m ""', $module_filename]);

    my @list_before = capture('test-tracker', 'list', '--git');
    my @tests_before = map { (/^\s+\d+\s+(.*)/)[0] } @list_before;
    my $found_test_before = grep { /^$test_filename$/ } @tests_before;
    ok($found_test_before, 'found test before rename of module');

    run_ok(['git', 'mv', $module_filename, 'untracked.pm']);

    my @list_after = capture('test-tracker', 'list', '--git');
    my @tests_after = map { (/^\s+\d+\s+(.*)/)[0] } @list_after;
    my $found_test_after = grep { /^$test_filename$/ } @tests_after;
    ok($found_test_after, 'found test after rename of module');
}

chdir $orig_cwd;
done_testing();
