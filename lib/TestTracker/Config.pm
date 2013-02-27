use strict;
use warnings;

package TestTracker::Config;

use File::Spec;
use IPC::System::Simple qw(capture);
use YAML;

sub _load {
    my $git_base_dir = git_base_dir();
    my $config_file = File::Spec->join($git_base_dir, '.test-tracker.conf');

    unless (-f $config_file) {
        die "config_file not found: $config_file";
    }
    unless (-r $config_file) {
        die "config_file not readable $config_file";
    }
    my ($config) = YAML::LoadFile($config_file);

    my @required_keys = qw(db_user db_password db_host db_prefix db_name module_regex test_regex lsf_log_dir);
    for my $required_key (@required_keys) {
        unless (exists $config->{$required_key}) {
            my $rel_config_file = File::Spec->abs2rel($config_file);
            print STDERR "$required_key not found in config: $rel_config_file\n";
            exit 1;
        }
    }

    return %$config;
}

my %config;
sub load {
    unless (keys %config) {
        %config = _load();
    }
    return %config;
}

# TODO git_base_dir is copy-pasted from TestTracker.  Need to refactor.

sub git_base_dir {
    my $git_dir = capture(qq(git rev-parse --git-dir));
    chomp $git_dir;
    my $abs_git_dir = File::Spec->rel2abs($git_dir);
    my $git_base_dir = (File::Spec->splitpath($abs_git_dir))[1];
    return $git_base_dir;
}

1;
