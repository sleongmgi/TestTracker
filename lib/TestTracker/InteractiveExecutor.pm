package TestTracker::InteractiveExecutor;

use strict;
use warnings;

use autodie qw(system);

sub main {
    my ($exec, $test_name) = @_;
    system(qq(bsub -I -q interactive "$exec" "$test_name"));
}

1;
