package TestTracker::Executor;

use strict;
use warnings;

use File::Path qw(make_path);
use File::Spec;
use IO::File;
use TestTracker;

sub main {
    my ($exec, $test_name) = @_;

    my $log_dir = $ENV{TESTTRACKER_LOG_DIR};
    unless ($log_dir) {
        die 'TESTTRACKER_LOG_DIR environment variable must be set!';
    }
    unless (-d $log_dir) {
        die "TESTTRACKER_LOG_DIR is not a directory: $log_dir";
    }

    my ($git_test_name) = TestTracker::rel2git($test_name);
    my $base_log_filename = File::Spec->join($log_dir, $git_test_name);

    my (undef, $base_log_dir, undef) = File::Spec->splitpath($base_log_filename);
    make_path($base_log_dir);
    unless (-d $base_log_dir) {
        die "failed to make_path: $base_log_dir";
    }

    my $out_filename = validated_log_filename("$base_log_filename.out");
    my $err_filename = validated_log_filename("$base_log_filename.err");

    # TODO catch bsub issues?
    system(qq(bsub -K -q short -o "$out_filename" -e "$err_filename" "$exec" "$test_name" 1> /dev/null 2> /dev/null));

    my (undef, $out_dir, undef) = File::Spec->splitpath($out_filename);
    system("touch '$out_dir'") && die "failed to execute touch";

    my $out_fh = IO::File->new($out_filename, 'r') or die "failed to open $out_filename";
    while (my $line = $out_fh->getline) {
        print $line;
    }

}

sub validated_log_filename {
    my $log_filename = shift;

    if (-f $log_filename) {
        die "file already exists: $log_filename";
    }

    return $log_filename;
}

1;
