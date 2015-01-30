package TestTracker::InteractiveExecutor;

use strict;
use warnings;

use IPC::Open3;
use Symbol qw(gensym);

sub main {
    my ($exec, $test_name) = @_;

    my $queue = $ENV{TEST_TRACKER_LSF_QUEUE} || 'short';

    my $job_regex = '^Job <[0-9]+> is submitted to queue <' . $queue . '>.$';

    # This redirects the first job submitted message to STDERR which is the
    # message for the bsub of the test itself but not any that might occur
    # during the test. Otherwise there will be a lot of these messages.
    # Be super careful with quoting!
    my $awk = qq|awk '{ if (/$job_regex/ && count++ == 0) print \\\$0 > \\"/dev/stderr\\"; else print \\\$0; }'|;
    my $cmd = qq(bash -c "set -o pipefail; bsub -Is -q $queue '$exec' '$test_name' | $awk");

    # Child's STDERR is "trapped" into CHLDERR and only shown if the child
    # exits non-zero, e.g. if it crashes. This keeps the output clean but still
    # helps with debugging.
    my $pid = open3(gensym, ">&STDOUT", \*CHLDERR, $cmd);
    my @stderr = <CHLDERR>;
    waitpid($pid, 0);
    if($? != 0) {
        print STDERR "\n\n";
        print STDERR "***** $test_name STDERR *****\n";
        print STDERR @stderr;
        print STDERR '*' x (length($test_name) + 19), "\n";
        print STDERR "\n";
    }
}

1;
