use strict;
use warnings;

package Test::System;
use base 'Test::Builder::Module';
our @EXPORT_OK = qw(run_ok);

use Test::More import => [qw(diag)];
use IPC::System::Simple qw(capture);

sub run_ok {
    my ($command, $test_name) = @_;
    my $tb = __PACKAGE__->builder;
    my @command = ref $command ? @$command : $command;
    $test_name //= @command > 1 ? join(' ', @command) : $command[0];
    my $output = eval { capture(@command) } || 'NO OUTPUT';
    $tb->ok($? == 0, $test_name) or diag $output;
}

#    my $child_exit_code = $? >> 8;
