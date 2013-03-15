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

    found_ok($tt_filename, "found uncommitted, tracked test file: '$tt_filename'");

    run_ok(['git', 'add', $tt_filename]);
    run_ok(['git', 'commit', '-m ""', $tt_filename]);
    run_ok(['git', 'clean', '-xdf']);

    found_ok($tt_filename, "found committed, tracked test file: '$tt_filename'");
}

{ # detect untracked test
    run_ok(['git', 'reset', '--hard', 'start']);
    run_ok(['git', 'clean', '-xdf']);

    my $tu_filename = 'untracked.t';
    ok((!grep { $_ eq $tu_filename } @test_filenames), 'verified untracked test file is not in test database');
    run_ok(['touch', $tu_filename]);
    found_ok($tu_filename, "found uncommitted, untracked test file: '$tu_filename'");

    run_ok(['git', 'add', $tu_filename]);
    run_ok(['git', 'commit', '-m ""', $tu_filename]);
    run_ok(['git', 'clean', '-xdf']);

    found_ok($tu_filename, "found committed, untracked test file: '$tu_filename'");
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

    found_ok($new_filename, 'found renamed test');
    not_found($filename, 'did not find previous test');
}

{ # detect same tests after module rename
    run_ok(['git', 'reset', '--hard', 'start']);
    run_ok(['git', 'clean', '-xdf']);

    my $test_filename = $test_filenames[0];
    not_found($test_filename, 'did not find test before module changed/created');

    my $module_filename = $test_db{$test_filename}->[0];
    run_ok(['touch', $module_filename]);
    run_ok(['git', 'add', $module_filename]);
    run_ok(['git', 'commit', '-m ""', $module_filename]);

    found_ok($test_filename, 'found test before rename of module');

    run_ok(['git', 'push']);

    my $new_module_filename = 'untracked.pm';
    run_ok(['git', 'mv', $module_filename, $new_module_filename]);
    found_ok($test_filename, 'found test after rename of module');

    run_ok(['git', 'commit', '-m ""']);
    found_ok($test_filename, 'found test after committing rename of module');
}

chdir $orig_cwd;
done_testing();

sub found_in_tt_list {
    my $file = shift;
    my @output = capture('test-tracker', 'list', '--git');
    my @files = map { strip_times($_) } @output;
    my $found = grep { /^$file$/ } @files;
    return ($found, @output);
}

sub found_ok {
    my ($file, $test_name) = @_;
    my ($found, @output) = found_in_tt_list($file);
    ok($found, $test_name) or diag @output;
}

sub not_found {
    my ($file, $test_name) = @_;
    my ($found, @output) = found_in_tt_list($file);
    ok(!$found, $test_name) or diag @output;
}

sub strip_times {
    my $line = shift;
    return ($line =~ /^\s+\d+\s+(.*)/)[0];
}
