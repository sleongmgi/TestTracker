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

    $lsf_log_dir
);

my $git_base_dir = git_base_dir();
my ($config) = YAML::LoadFile(File::Spec->join($git_base_dir, '.test-tracker.conf'));

our $db_user     = $config->{db_user};
our $db_password = $config->{db_password};
our $db_host     = $config->{db_host};
our $db_schema   = $config->{db_schema};
our $db_name     = $config->{db_name};

our $filter_inc_regex = $config->{filter_inc_regex};

our $lsf_log_dir = $config->{lsf_log_dir};

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
