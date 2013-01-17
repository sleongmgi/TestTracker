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
    my $dsn = sprintf('dbi:Pg:dbname=%s;host=%s', $config{db_name}, $config{db_host});
    my $dbh = DBI->connect(
        $dsn, $config{db_user}, $config{db_password}, {RaiseError => 1, AutoCommit => 0}
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
    my @git_log_args = @_;

    my %config = TestTracker::Config::load();

    my $git_log_cmd = sprintf(q(git log --pretty="format:" --name-only "%s"), join('" "', @git_log_args));
    my @commited_changed_files = capture($git_log_cmd);
    chomp @commited_changed_files;

    # TODO this does not account for renames, e.g. "R  foo -> bar"
    my @working_changed_files = capture(q(git status --porcelain | awk '{print $2}'));
    chomp @working_changed_files;

    my $git_base_dir = git_base_dir();

    my @changed_files =
        grep { /$config{test_regex}|$config{module_regex}/ }
        grep { $_ !~ /^$/ }
        @commited_changed_files, @working_changed_files;

    return @changed_files;
}

sub _durations_for_tests {
    my ($dbh, $db_schema, @tests) = @_;

    my $sql = sprintf(qq{
        SELECT name, duration FROM $db_schema.test
        WHERE name IN (%s)
        }, join(', ', map { '?' } @tests));

    my @results = $dbh->selectall_arrayref($sql, {}, @tests);
    @results = sort {$b->[1] <=> $a->[1]} @{$results[0]};
    return @results
}

# returns an array of two element arrays (test_name, duration), sorted by duration.
sub durations_for_tests {
    unless (@_) {
        croak 'times_for_tests takes one or more test filenames (git_files)';
    }
    my %config = TestTracker::Config::load();
    my $dbh = db_connection();
    my @results = _durations_for_tests($dbh, $config{db_schema}, @_);
    $dbh->disconnect();
    return @results;
}


sub _modules_for_test {
    my ($dbh, $db_schema, $test, @modules) = @_;

    my $sql = sprintf(qq{
        SELECT $db_schema.module.name FROM $db_schema.module JOIN
        $db_schema.module_test ON $db_schema.module.id = $db_schema.module_test.module_id JOIN
        $db_schema.test ON $db_schema.module_test.test_id = $db_schema.test.id
        WHERE $db_schema.test.name = ? AND $db_schema.module.name IN (%s)
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
        my @modules = _modules_for_test($dbh, $config{db_schema}, $test, @relevant_modules);
        $results{$test} = \@modules;
    }
    $dbh->disconnect();
    return %results;
}

sub _tests_for_modules {
    my ($dbh, $db_schema, @modules) = @_;

    my $sql = sprintf(qq{
        SELECT DISTINCT($db_schema.test.name) FROM $db_schema.module_test
        JOIN $db_schema.test ON $db_schema.test.id = $db_schema.module_test.test_id
        JOIN $db_schema.module ON $db_schema.module.id = $db_schema.module_test.module_id
        WHERE $db_schema.module.name IN (%s)
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
    return _tests_for_modules($dbh, $config{db_schema}, @_);
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

sub tests_for_git_changes {
    my @git_log_args = @_;

    my %config = TestTracker::Config::load();

    my @changed_files = changed_files_from_git(@git_log_args);

    my @tests;
    if (@changed_files) {
        push @tests, tests_for_git_files(@changed_files);
        push @tests, grep { /$config{test_regex}/ } @changed_files;
    }

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

    my $pt_parser = new Getopt::Long::Parser config => ['pass_through'];
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
        $os_parser->configure('pass_through');
    }
    $os_parser->getoptions(@custom_options) or pod2usage(2);

    return %options;
}

sub default_git_arg {
    my $branch_name = capture('git rev-parse --abbrev-ref HEAD');
    chomp $branch_name;

    # TODO what if the config doesn't exist?
    my $remote = capture(qq(git config branch.$branch_name.remote));
    chomp $remote;

    my $remote_ref = capture(qq(git config branch.$branch_name.merge));
    chomp $remote_ref;

    my ($remote_branch_name) = $remote_ref =~ /refs\/heads\/(.*)/;

    my $remote_branch = join('/', $remote, $remote_branch_name);
    if (system("git rev-parse --abbrev-ref $remote_branch > /dev/null") != 0) {
        die 'Failed to infer default_git_arg!';
    }

    return "$remote_branch..";
}

sub format_duration {
    my $duration = shift;

    my $hours = int($duration/3600);
    my $remainder = $duration - $hours*3600;

    my $minutes = int($remainder/60);
    my $seconds = $remainder - $minutes*60;

    return sprintf("%02d:%02d:%02d", $hours, $minutes, $seconds);
}

1;
