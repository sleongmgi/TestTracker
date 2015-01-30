use strict;
use warnings;

use Cwd qw(realpath);
use File::Basename qw(dirname);
use lib realpath(dirname(__FILE__) . '/..');

package Test::TestTracker;
use base 'Test::Builder::Module';

our @EXPORT_OK = qw(
    db_filename
    conf_filename
    create_a_repo
    create_a_config
    create_a_database
);

use Carp qw(croak);
use Cwd qw(cwd);
use Test::More;
use Test::System import => [qw(run_ok)];
use File::Temp qw();

sub db_filename { '.test-tracker.db' }
sub conf_filename { '.test-tracker.conf' }

sub create_a_repo {
    my $base_dir = shift;
    my $bare_dir = File::Spec->join($base_dir, 'repo.git');
    my $work_dir = File::Spec->join($base_dir, 'work');

    my $tb = __PACKAGE__->builder();
    $tb->ok(-d $base_dir, "verified base directory exists");

    run_ok(['git', 'init', '--bare', $bare_dir], 'initialized a bare repo');
    run_ok(['git', 'clone', "file://$bare_dir", $work_dir]);

    my $orig_dir = cwd();
    chdir $work_dir;
    run_ok(['touch', 'README.md']);
    run_ok(['git', 'add', 'README.md']);
    run_ok(['git', 'commit', '-m ""', 'README.md']);
    run_ok(['git', 'push', '-u', 'origin', 'master']);
    chdir $orig_dir;

    return $work_dir;
}

sub create_a_config {
    my $dir = cwd();
    my $tb = __PACKAGE__->builder();
    my $conf_filename = File::Spec->join($dir, conf_filename());
    my $db_filename = File::Spec->join($dir, db_filename());
    $tb->ok(! -e $conf_filename, 'verified config file does not already exist');
    my %conf = (
        db_dsn => "dbi:SQLite:dbname=$db_filename",
        db_password => 'password',
        db_prefix => '',
        db_user => 'user',
        module_regex => '\.pm$',
        test_regex => '\.t$',
    );
    YAML::DumpFile($conf_filename, \%conf);
    $tb->ok(-s $conf_filename, 'prepared a config file');

    return %conf;
}

sub create_a_database {
    my $dir = cwd();
    my $tb = __PACKAGE__->builder();
    my $db_filename = File::Spec->join($dir, db_filename());
    $tb->ok(! -e $db_filename, 'verified database file does not already exist');
    my $dbh = TestTracker->db_connection();
    $dbh->do(qq{CREATE TABLE module (id integer primary key autoincrement, name text);});
    $dbh->do(qq{CREATE TABLE test (id integer primary key autoincrement, name text, duration integer);});
    $dbh->do(qq{CREATE TABLE module_test (module_id integer references module(module_id), test_id integer references test(test_id));});

    my ($test_id, $module_id);
    my %test_db = (
        'tracker.t' => [qw(tracker.pm lister.pm)],
    );
    for my $test_filename (keys %test_db) {
        my @module_filenames = @{$test_db{$test_filename}};
        my $duration = int(10 * rand());
        $test_id++;
        $dbh->do(qq{INSERT INTO test (id, name, duration) values ($test_id, '$test_filename', $duration);});
        for my $module_filename (@module_filenames) {
            $module_id++;
            $dbh->do(qq{INSERT INTO module (id, name) values ($module_id, '$module_filename');});
            $dbh->do(qq{INSERT INTO module_test (module_id, test_id) values ($module_id, $test_id);});
        }
    }

    $dbh->commit();
    $dbh->disconnect();
    $tb->ok(-s $db_filename, 'prepared a database file');

    return %test_db;
}

1;
