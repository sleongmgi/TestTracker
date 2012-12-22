package TestTracker;

use strict;
use warnings;

use IPC::System::Simple; # needed for autodie's :system
use autodie qw(:system);
use DBI;
use File::Spec;
use Getopt::Long;
use Pod::Usage;
use TestTracker::Config qw($db_user $db_password $db_host $db_schema $db_name);

use Carp qw(croak);

sub db_connection {
    my $dsn = sprintf('dbi:Pg:dbname=%s;host=%s', $db_name, $db_host);
    my $dbh = DBI->connect(
        $dsn, $db_user, $db_password, {RaiseError => 1, AutoCommit => 0}
    ) or die $DBI::errstr;
    return $dbh;
}

sub git_base_dir {
    my $git_dir = qx_autodie(qq(git rev-parse --git-dir));
    chomp $git_dir;
    my $abs_git_dir = File::Spec->rel2abs($git_dir);
    my $git_base_dir = (File::Spec->splitpath($abs_git_dir))[1];
    return $git_base_dir;
}

sub changed_files_from_git {
    my @git_log_args = @_;
    my $git_log_cmd = sprintf(q(git log --pretty="format:" --name-only "%s"), join('" "', @git_log_args));
    my @commited_changed_files = qx_autodie($git_log_cmd);
    chomp @commited_changed_files;

    # TODO this does not account for renames, e.g. "R  foo -> bar"
    my @working_changed_files = qx_autodie(q(git status --porcelain | awk '{print $2}'));
    chomp @working_changed_files;

    my $git_base_dir = git_base_dir();

    my @changed_files =
        grep { $_ !~ /^$/ }
        @commited_changed_files, @working_changed_files;

    return @changed_files;
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
    my $dbh = db_connection();
    return _tests_for_modules($dbh, $db_schema, @_);
}

sub git_path {
    my $abs_path = shift;

    unless ($abs_path) {
        croak 'git_path takes one argument';
    }

    my $git_base_dir = git_base_dir();
    my ($git_path) = $abs_path =~ /^${git_base_dir}(.*)$/;

    return $git_path;
}

sub git_files {
    my @files = @_;
    return map { git_path($_) } @files;
}

sub absolute_path {
    my $git_path = shift;

    unless ($git_path) {
        croak 'absolute_path takes one argument';
    }

    my $git_base_dir = git_base_dir();
    my $abs_path = File::Spec->join($git_base_dir, $git_path);

    return $abs_path;
}

sub absolute_files {
    my @files = @_;
    return map { absolute_path($_) } @files;
}

sub tests_for_git_changes {
    my @git_log_args = @_;
    my @changed_files = changed_files_from_git(@git_log_args);
    my @tests;
    if (@changed_files) {
        push @tests, tests_for_git_files(@changed_files);
    }
    # Convert "git path" to "absolute path" and then to "relative path"
    my @rel_tests = map { File::Spec->abs2rel($_) } absolute_files(@tests);
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

sub qx_autodie {
    my $cmd = shift;

    my @rv = qx($cmd);
    if ($? != 0) {
        if ($? == -1) {
            die qq{"$cmd" failed to start};
        } else {
            my $exit_code = $? >> 8;
            die qq{"$cmd" failed ($exit_code)};
        }
    }

    if (wantarray) {
        return @rv;
    } else {
        return join('', @rv);
    }
}

sub default_git_arg {
    my $branch_name = qx_autodie('git rev-parse --abbrev-ref HEAD');
    chomp $branch_name;

    my $remote = qx(git config branch.$branch_name.remote);
    chomp $remote;

    my $remote_ref = qx(git config branch.$branch_name.merge);
    chomp $remote_ref;

    my ($remote_branch_name) = $remote_ref =~ /refs\/heads\/(.*)/;

    my $remote_branch = join('/', $remote, $remote_branch_name);
    if (system("git rev-parse --abbrev-ref $remote_branch > /dev/null") != 0) {
        die 'Failed to infer default_git_arg!';
    }

    return "$remote_branch..";
}

1;
