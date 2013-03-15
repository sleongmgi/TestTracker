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
run_ok(['git', 'clean', '-xdf']);

my @test_filenames = keys %test_db;
ok(@test_filenames > 0, 'test database has tracked tests');

my $tt_filename = $test_filenames[0];
run_ok(['touch', $tt_filename]);
my @found_ut_capture = TestTracker::changed_files_from_git($git_arg);
my $found_ut = grep { $_ =~ /^$tt_filename$/ } @found_ut_capture;
ok($found_ut, "found uncommitted, tracked test file: '$tt_filename'")
    or diag(join("\n", @found_ut_capture));

run_ok(['git', 'add', $tt_filename]);
run_ok(['git', 'commit', '-m ""', $tt_filename]);
my @found_ct_capture = TestTracker::changed_files_from_git($git_arg);
my $found_ct = grep { $_ =~ /^$tt_filename$/ } @found_ct_capture;
ok($found_ct, "found committed, tracked test file: '$tt_filename'")
    or diag(join("\n", @found_ct_capture));

run_ok(['git', 'rm', $tt_filename]);
run_ok(['git', 'commit', '-m ""', $tt_filename]);
my @found_rt_capture = TestTracker::changed_files_from_git($git_arg);
my $found_rt = grep { $_ =~ /^$tt_filename$/ } @found_rt_capture;
ok(!$found_rt, "did not find removed test file: '$tt_filename'")
    or diag(join("\n", @found_rt_capture));

my $tu_filename = 'untracked.t';
ok((!grep { $_ eq $tu_filename } @test_filenames), 'verified untracked test file is not in test database');
run_ok(['touch', $tu_filename]);
my @found_uu_capture = TestTracker::changed_files_from_git($git_arg);
my $found_uu = grep { $_ =~ /^$tu_filename$/ } @found_uu_capture;
ok($found_uu, "found uncommitted, untracked test file: '$tu_filename'")
    or diag(join("\n", @found_uu_capture));

run_ok(['git', 'add', $tu_filename]);
run_ok(['git', 'commit', '-m ""', $tu_filename]);
my @found_cu_capture = TestTracker::changed_files_from_git($git_arg);
my $found_cu = grep { $_ =~ /^$tu_filename$/ } @found_cu_capture;
ok($found_cu, "found committed, untracked test file: '$tu_filename'")
    or diag(join("\n", @found_cu_capture));

my $subdir = 'subdir';
mkdir $subdir;
chdir $subdir;
my @found_subdir_capture = TestTracker::changed_files_from_git($git_arg);
my $found_subdir = scalar @found_subdir_capture;
ok($found_subdir, "found changes from within a subdir")
    or diag(join("\n", @found_subdir_capture));

chdir $orig_cwd;
done_testing();
