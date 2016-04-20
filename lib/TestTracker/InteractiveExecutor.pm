package TestTracker::InteractiveExecutor;

use strict;
use warnings;

use IPC::Run (qw(run));

=head2 main

Executor main function.

PARAM: $exec, $test_name
RETURNS: <none>

=cut

sub main {
    @_ == 2 or die 'ERROR: Expecting 2 parameters but found ' . scalar(@_) . '.';
    execute( @_, $ENV{'TEST_TRACKER_LSF_QUEUE'} || 'short' );
}

=head2 execute

Execute the shell command.

Child's STDERR is "trapped" into CHLDERR and only shown if the child
exits non-zero, e.g. if it crashes. This keeps the output clean but still
helps with debugging.

PARAMS: $exec, $test_name, $queue
RETURNS: <none>

=cut

sub execute {
    my ( $exec, $test_name, $queue ) = @_;

    my ( $stdout, $stderr ) = ('', '');
    run( construct_bsub_command( $exec, $test_name, $queue ), '<pty<', \undef, '>pty>', \$stdout, '2>', \$stderr )
        or do {
        return print_error_message( $exec, $test_name, $?, $stderr, $stdout );
        };
    print $stdout;

}

=head2 construct_bsub_command

Construct bsub command.

This redirects the first job submitted message to STDERR which is the
message for the bsub of the test itself but not any that might occur
during the test. Otherwise there will be a lot of these messages.
Be super careful with quoting!

PARAMS: $exec, $test_name, $queue
RETURNS: $array_ref_of_command

=cut

sub construct_bsub_command {
    my ( $exec, $test_name, $queue ) = @_;
    my $job_regex = '^Job <[0-9]+> is submitted to queue <' . $queue . '>.$';

    my $awk
        = qq|awk '{ if (/$job_regex/ && count++ == 0) print \$0 > "/dev/stderr"; else print \$0; }'|;
    return [ 'bash', '-c', "set -o pipefail; bsub -Is -q $queue '$exec' '$test_name' | $awk" ];
}

=head2 print_error_message

Print the error message out to the STDERR.

PARAMS: $exec, $test_name, $error_code, $stderr_message, $stdout_message
RETURNS: <none>

=cut

sub print_error_message {
    my ( $exec, $test_name, $error_code, $stderr, $stdout ) = @_;
    my $error_message = <<EOT;
***** $test_name STDERR *****
ERROR CODE: $error_code
$stderr
***** $test_name STDOUT *****
$stdout
EOT
    print STDERR ( $error_message, ( '*' x ( length($test_name) + 19 ) ), "\n" );
}

1;
