package TestTracker::Config;

use YAML;
use File::Spec;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    $db_user
    $db_password
    $db_host
    $db_schema
    $db_name

    $filter_inc_regex
    $test_regex

    $lsf_log_dir
);

my $git_base_dir = git_base_dir();
my $config_file = File::Spec->join($git_base_dir, '.test-tracker.conf');
my ($config) = YAML::LoadFile($config_file);

my $req_config = sub {
    my $key = shift;
    my $value = $config->{$key};
    unless (defined $value) {
        my $rel_config_file = File::Spec->abs2rel($config_file);
        print STDERR "$key not found in config: $rel_config_file\n";
        exit 1;
    }
    return $value;
};

our $db_user     = $req_config->('db_user');
our $db_password = $req_config->('db_password');
our $db_host     = $req_config->('db_host');
our $db_schema   = $req_config->('db_schema');
our $db_name     = $req_config->('db_name');

our $filter_inc_regex = $req_config->('filter_inc_regex');
our $test_regex       = $req_config->('test_regex');

our $lsf_log_dir = $req_config->('lsf_log_dir');

# TODO Both git_base_dir and qx_autodie are copy-pasted from TestTracker.
# Need to refactor.

sub git_base_dir {
    my $git_dir = qx_autodie(qq(git rev-parse --git-dir));
    chomp $git_dir;
    my $abs_git_dir = File::Spec->rel2abs($git_dir);
    my $git_base_dir = (File::Spec->splitpath($abs_git_dir))[1];
    return $git_base_dir;
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
