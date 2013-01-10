use strict;
use warnings;

use Test::More;
use TestTracker;
use File::Basename qw(basename);

my ($method) = basename(__FILE__) =~ /(.*)\.t$/;
ok(TestTracker->can($method), qq(TestTracker can $method));

{
    local $@ = '';
    eval { TestTracker::qx_autodie('false') };
    isnt($@, '', q(qx_autodie('false') died when expected));
}

{
    local $@ = '';
    eval { TestTracker::qx_autodie('true') };
    is($@, '', q(qx_autodie('true') succeed));
}

{
    my @in = (1, 2, 3);
    my $in = join('\n', @in);
    my @out = TestTracker::qx_autodie(qq(/bin/echo -e "$in"));
    chomp @out;
    is(scalar(@out), 3, 'qx_autodie returns list in list content');
    is_deeply(\@out, \@in, 'qx_autodie returns correct list in list content');
}

{
    my @in = (1, 2, 3);
    my $in = join('\n', @in);
    my $expected = join("\n", @in);
    my $out = TestTracker::qx_autodie(qq(/bin/echo -e "$in"));
    chomp $out;
    is($out, $expected, 'qx_autodie returns correct string in scalar context');
}

done_testing();
