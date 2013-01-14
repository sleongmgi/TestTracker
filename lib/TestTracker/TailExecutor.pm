package TestTracker::TailExecutor;

use strict;
use warnings;

use File::Path qw(make_path);
use File::Spec;
use IO::File;
use POSIX ":sys_wait_h";
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
    printf STDERR "$out_filename\n";

    # TODO catch bsub issues?

    my $bsub_pid = fork();
    unless (defined $bsub_pid) {
        die "cannot fork to bsub";
    }
    if ($bsub_pid == 0) {
        system(qq(bsub -K -q short -o "$out_filename" -e "$err_filename" "$exec" "$test_name" 1> /dev/null 2> /dev/null));
        exit 0;
    } else {
        print STDERR "Waiting for log files...\n";
        wait_for_file($out_filename);
        wait_for_file($err_filename);

        print STDERR "Tailing log files...\n";
        wait_for_file($out_filename);
        my $tail_pid = fork();
        unless (defined $tail_pid) {
            die "cannot fork to tail";
        }
        if ($tail_pid == 0) {
            system(qq(tail -q -n 100 -f "$out_filename" "$err_filename"));
            exit 0;
        } else {
            # parent process
            my $bsub_active;
            do {
                $bsub_active = waitpid($bsub_pid, WNOHANG);
                expire_file_cache($out_filename);
                expire_file_cache($err_filename);
            } while $bsub_active > 0;
            system(qq(kill $tail_pid));
        }
    }
}

sub expire_file_cache {
    my $filename = shift;
    my (undef, $base_dir, undef) = File::Spec->splitpath($filename);
    my $log_dir_uid = (stat($base_dir))[4];
    system(qq(chown $log_dir_uid "$base_dir"));
    my $rv = opendir(my $dh, $base_dir);
    closedir $dh if ($rv);
}

sub wait_for_file {
    my $filename = shift;
    my $timeout  = shift || 60;

    my $start_time = time();
    while (! -e $filename) {
        if (time() - $start_time >= $timeout) {
            die "timed out while waiting for log file: $filename";
        }
        expire_file_cache($filename);
    }

    return $filename;
}

sub validated_log_filename {
    my $log_filename = shift;

    if (-f $log_filename) {
        die "file already exists: $log_filename";
    }

    return $log_filename;
}

1;
