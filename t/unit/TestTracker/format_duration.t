use strict;
use warnings;

use Test::More;
use TestTracker;
use File::Basename qw(basename);

my ($method) = basename(__FILE__) =~ /(.*)\.t$/;
ok(TestTracker->can($method), qq(TestTracker can $method));

{
    my @in = (
        [   0, '00:00:00'],
        [   6, '00:00:06'],
        [  60, '00:01:00'],
        [ 600, '00:10:00'],
        [6000, '01:40:00'],
    );
    for my $in (@in) {
        my ($s, $e) = @$in;
        my $t = TestTracker::format_duration($s);
        is($t, $e, qq(got correct output for $s seconds));
    }
}
done_testing();
