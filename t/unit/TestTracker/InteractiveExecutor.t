use strict;
use warnings;

use Test::More;
use Sub::Override;
use Try::Tiny;

use_ok('IPC::Run');
use_ok('TestTracker::InteractiveExecutor');

subtest 'test arguments' => sub {
    my @arguments = ( 'what', 'ever', 'work' );
    for ( 0, 1, 3 ) {
        eval { TestTracker::InteractiveExecutor::main( @arguments[ 0 .. ( $_ - 1 ) ] ); };
        like(
            $@,
            qr/ERROR: Expecting 2 parameters but found $_\./,
            "should not have [$_ argument"
                . ( $_ == 1 ? ''     : 's' ) . '] '
                . ( $_ > 2  ? 'more' : 'less' )
                . ' than 2 arguments'
        );
    }
};

subtest 'test command' => sub {
    my $sub_override = Sub::Override->new();
    $sub_override->replace(
        'TestTracker::InteractiveExecutor::run' => sub {
            is_deeply(
                $_[0],
                [   'bash',
                    '-c',
                    q{set -o pipefail; bsub -Is -q test 'what' 'ever' | awk '{ if (/^Job <[0-9]+> is submitted to queue <test>.$/ && count++ == 0) print $0 > "/dev/stderr"; else print $0; }'}
                ],
                'correct command',
            );
        }
    );

    local $ENV{TEST_TRACKER_LSF_QUEUE} = 'test';
    TestTracker::InteractiveExecutor::main( 'what', 'ever' );

};

done_testing;
