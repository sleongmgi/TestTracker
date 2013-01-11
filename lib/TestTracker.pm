use strict;
use warnings;

package TestTracker;

use Carp qw(croak);
use DBI;
use File::Spec;
use Getopt::Long;
use IPC::System::Simple qw(capture);
use List::MoreUtils qw(uniq);
use Pod::Usage;
use TestTracker::Config;
use autodie qw(:system);

sub db_connection {
    my %config = TestTracker::Config::load();
    my $dbh = DBI->connect(
        $config{db_dsn}, $config{db_user}, $config{db_password}, {RaiseError => 1, AutoCommit => 0}
    ) or die $DBI::errstr;
    return $dbh;
}

sub git_base_dir {
    my $git_dir = capture(qq(git rev-parse --git-dir));
    chomp $git_dir;
    my $abs_git_dir = File::Spec->rel2abs($git_dir);
    my $git_base_dir = (File::Spec->splitpath($abs_git_dir))[1];
    return $git_base_dir;
}

sub changed_files_from_git {
    my @git_args = @_;

    my @cmd = qw(git diff --name-only);
    if (@git_args) {
        push @cmd, @git_args;
    }

    my @files = capture(@cmd);

    my @git_sz = git_status_z();
    my @untracked_lines = grep { git_sz_is_untracked($_) } @git_sz;
    my @untracked_files = map { (parse_git_status_z_line($_))[2] } @untracked_lines;

    push @files, @untracked_files;
    chomp @files;

    my %config = TestTracker::Config::load();
    @files =
        uniq
        grep {
            (-e (git2rel($_))[0] && /$config{test_regex}/) # only existing tests are reported or ...
            || /$config{module_regex}/                     # any modules in order to handle renames
        }
        @files;

    return @files;
}

sub _durations_for_tests {
    my ($dbh, $db_prefix, @tests) = @_;

    my $sql = sprintf(qq{
        SELECT name, duration FROM ${db_prefix}test
        WHERE name IN (%s)
        }, join(', ', map { '?' } @tests));

    my @results = $dbh->selectall_arrayref($sql, {}, @tests);
    @results = sort {$b->[1] <=> $a->[1]} @{$results[0]};

    for my $test (@tests) {
        unless (grep { $_->[0] eq $test } @results) {
            push @results, [$test, 0];
        }
    }
    return @results
}

# returns an array of two element arrays (test_name, duration), sorted by duration.
sub durations_for_tests {
    unless (@_) {
        croak 'times_for_tests takes one or more test filenames (git_files)';
    }
    my %config = TestTracker::Config::load();
    my $dbh = db_connection();
    my @results = _durations_for_tests($dbh, $config{db_prefix}, @_);
    $dbh->disconnect();
    return @results;
}


sub _modules_for_test {
    my ($dbh, $db_prefix, $test, @modules) = @_;

    my $sql = sprintf(qq{
        SELECT ${db_prefix}module.name FROM ${db_prefix}module JOIN
        ${db_prefix}module_test ON ${db_prefix}module.id = ${db_prefix}module_test.module_id JOIN
        ${db_prefix}test ON ${db_prefix}module_test.test_id = ${db_prefix}test.id
        WHERE ${db_prefix}test.name = ? AND ${db_prefix}module.name IN (%s)
    }, join(', ', map { '?' } @modules));

    my @module_names = map { $_->[0] } @{$dbh->selectall_arrayref($sql, {}, $test, @modules)};
    return @module_names;
}

# returns a hash of test_name => [modules]
sub modules_for_tests {
    my ($tests, $relevant_modules) = @_;
    my @tests = @{$tests};
    my @relevant_modules = @{$relevant_modules};

    unless (@tests) {
        croak 'times_for_tests takes one or more test filenames (git_files)';
    }
    my %config = TestTracker::Config::load();
    my $dbh = db_connection();
    my %results;
    for my $test (@tests) {
        my @modules = _modules_for_test($dbh, $config{db_prefix}, $test, @relevant_modules);
        $results{$test} = \@modules;
    }
    $dbh->disconnect();
    return %results;
}

sub _tests_for_modules {
    my ($dbh, $db_prefix, @modules) = @_;

    my $sql = sprintf(qq{
        SELECT DISTINCT(${db_prefix}test.name) FROM ${db_prefix}module_test
        JOIN ${db_prefix}test ON ${db_prefix}test.id = ${db_prefix}module_test.test_id
        JOIN ${db_prefix}module ON ${db_prefix}module.id = ${db_prefix}module_test.module_id
        WHERE ${db_prefix}module.name IN (%s)
        }, join(', ', map { '?' } @modules));

    my @test_names = map { $_->[0] } @{$dbh->selectall_arrayref($sql, {}, @modules)};
    return @test_names;
}

sub tests_for_git_files {
    unless (@_) {
        croak 'tests_for_git_files takes one or more module paths';
    }
    my %config = TestTracker::Config::load();
    my $dbh = db_connection();
    return _tests_for_modules($dbh, $config{db_prefix}, @_);
}

sub all_tracked_tests {
    my %config = TestTracker::Config::load();
    my $dbh = db_connection();
    my $db_prefix = $config{db_prefix};
    my $sql = qq(SELECT name FROM ${db_prefix}test;);
    my @test_names = map { $_->[0] } @{$dbh->selectall_arrayref($sql)};
    return @test_names;
}

sub _validate_paths {
    my @paths = @_;

    unless (@paths) {
        return 'one or more arguments required';
    }

    my @ne_paths = grep { ! -e $_ } @paths;
    if (@ne_paths) {
        my $msg = sprintf('one or more relative paths do not exist: %s',
            join(', ', @ne_paths));
        return $msg;
    }

    return;
}

sub _rel2git {
    my $rel_path = shift;
    my $abs_path = File::Spec->rel2abs($rel_path);
    my ($git_path) = abs2git($abs_path);
    return $git_path;
}


sub rel2git {
    my @rel_paths = @_;

    my $error = _validate_paths(@rel_paths);
    if ($error) {
        croak "rel2git: $error";
    }

    return map { _rel2git($_) } @rel_paths;
}

sub _abs2git {
    my $abs_path = shift;
    my $git_base_dir = git_base_dir();
    my ($git_path) = $abs_path =~ /^${git_base_dir}(.*)$/;
    return $git_path;
}

sub abs2git {
    my @abs_paths = @_;

    my $error = _validate_paths(@abs_paths);
    if ($error) {
        croak "rel2git: $error";
    }

    return map { _abs2git($_) } @abs_paths;
}

sub _git2rel {
    my $git_path = shift;

    my $abs_path = _git2abs($git_path);
    my $rel_path = File::Spec->abs2rel($abs_path);

    return $rel_path;
}

sub git2rel {
    my @git_paths = @_;

    unless (@git_paths) {
        croak 'git2rel: one or more arguments required';
    }

    return map { _git2rel($_) } @git_paths;
}

sub _git2abs {
    my $git_path = shift;

    my $git_base_dir = git_base_dir();
    my $abs_path = File::Spec->join($git_base_dir, $git_path);

    return $abs_path;
}

sub git2abs {
    my @git_paths = @_;

    unless (@git_paths) {
        croak 'git2abs: one or more arguments required';
    }

    return map { _git2abs($_) } @git_paths;
}

sub _git2rel {
    my $git_path = shift;

    my $abs_path = _git2abs($git_path);
    my $rel_path = File::Spec->abs2rel($abs_path);

    return $rel_path;
}

sub git2rel {
    my @git_paths = @_;

    unless (@git_paths) {
        croak 'git2rel: one or more arguments required';
    }

    return map { _git2rel($_) } @git_paths;
}

sub tests_for_git_changes {
    my @git_log_args = @_;

    my %config = TestTracker::Config::load();

    my @changed_files = changed_files_from_git(@git_log_args);

    my @tests;
    if (@changed_files) {
        push @tests, tests_for_git_files(@changed_files);
        push @tests, grep { /$config{test_regex}/ } @changed_files;
    }
    return unless @tests;

    # Convert "git path" to "absolute path" and then to "relative path"
    my @rel_tests = uniq map { File::Spec->abs2rel($_) } git2abs(@tests);
    return grep { -f $_ } @rel_tests;
}

sub parse_args {
    my %option_spec = @_;

    my $pass_through  = delete $option_spec{pass_through};

    my %options;

    my ($help, $man);
    my %common_options = (
        'help|h|?' => \$help,
        'man'      => \$man,
        'git|g:s'  => \$options{git},
        'debug'    => \$options{debug},
    );

    my @custom_options;
    for my $option_name (keys %option_spec) {
        push @custom_options, $option_spec{$option_name} => \$options{$option_name};
    }

    my $pt_parser = new Getopt::Long::Parser config => ['pass_through', 'no_ignore_case'];
    $pt_parser->getoptions(%common_options);
    pod2usage(1) if $help;
    pod2usage(-exitstatus => 0, -verbose => 2) if $man;

    # --git is an optional string argument so if it is passed as last option and the users also passes an argument (test or module path) then Getopt::Long may mistakenly identify that as the value to this option. So we check if it is a file and throw it back on @ARGV if so.
    if ($options{git} && -f $options{git}) {
        unshift @ARGV, $options{git};
    }

    if (defined($options{git}) && $options{git} eq '') {
        $options{git} = default_git_arg();
    }

    my $os_parser = new Getopt::Long::Parser;
    if ($pass_through) {
        $os_parser->configure('pass_through', 'no_ignore_case');
    }
    $os_parser->getoptions(@custom_options) or pod2usage(2);

    return %options;
}

sub default_git_arg {
    return '@{u}';
}

sub format_duration {
    my $duration = shift;

    my $hours = int($duration/3600);
    my $remainder = $duration - $hours*3600;

    my $minutes = int($remainder/60);
    my $seconds = $remainder - $minutes*60;

    return sprintf("%02d:%02d:%02d", $hours, $minutes, $seconds);
}

sub git_status_z {
    my @lines = capture('git', 'status', '-zs');
    return @lines;
}

sub parse_git_status_z_line {
    my $line = shift;
    my ($x, $y, $paths) = $line =~ /(.)(.) (.*)/;
    unless ($x) {
        print STDERR "failed to parse status line: $line\n";
    }
    my ($now, $was) = split(/\0/, $paths);
    return ($x, $y, $now, $was);
}

sub git_sz_is_untracked {
    my $line = shift;
    my ($x, $y) = parse_git_status_z_line($line);
    return ($x eq '?' && $y eq '?');
}

sub get_test_id {
    my ($dbh, $db_prefix, $test_name) = @_;
    unless ($test_name) {
        die 'test_name should always be specified.';
    }
    my $sql = qq{SELECT id FROM ${db_prefix}test WHERE name = ?};
    my $test_id = ($dbh->selectrow_array($sql, {}, $test_name))[0];
    unless ($test_id) {
        croak "failed to get ID for test: $test_name";
    }
    return $test_id;
}

sub delete_test_by_id {
    my ($dbh, $db_prefix, $test_id) = @_;

    my $delete_model_test_sth = $dbh->prepare(qq{DELETE FROM ${db_prefix}module_test WHERE test_id = ?});
    $delete_model_test_sth->execute($test_id);

    my $delete_test_sth = $dbh->prepare(qq{DELETE FROM ${db_prefix}test WHERE id = ?});
    $delete_test_sth->execute($test_id);
}

1;
