use strict;
use warnings;

use Cwd qw(cwd realpath);
use File::Basename qw(dirname);

my $lib_dir;
BEGIN {
    $lib_dir  = realpath(dirname(__FILE__) . '/../../../lib');
}

use lib $lib_dir;

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

my $test_dir = File::Temp->newdir(TMPDIR => 1);
my $git_dir = create_a_repo($test_dir);
chdir $git_dir;

my $git_arg = TestTracker::default_git_arg();

my $db_filename = db_filename();
my $conf_filename = conf_filename();

my %config = create_a_config();
run_ok(['git', 'add', $conf_filename]);
run_ok(['git', 'commit', '-m ""', $conf_filename]);

my %test_db = create_a_database();
run_ok(['git', 'add', $db_filename]);
run_ok(['git', 'commit', '-m ""', $db_filename]);

run_ok(['git', 'tag', '-a', '-m', '', 'start'], 'tagged repo as "start"');
run_ok(['git', 'reset', '--hard', 'start']);
run_ok(['git', 'clean', '-xdf']);

my @test_filenames = sort keys %test_db;
ok(@test_filenames > 0, 'test database has tracked tests');

my @all_tracked_tests = TestTracker::all_tracked_tests();
@all_tracked_tests = sort @all_tracked_tests;
is_deeply(\@all_tracked_tests, \@test_filenames, 'got all tracked tests');

chdir $orig_cwd;
done_testing();
