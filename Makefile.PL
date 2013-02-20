
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Track Perl module and test relationships so you can guess what are the best tests to run.",
  "AUTHOR" => "dmorton and nnutter",
  "BUILD_REQUIRES" => {
    "File::Basename" => 0,
    "Test::More" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "TestTracker",
  "EXE_FILES" => [
    "bin/test-tracker",
    "bin/test-tracker-prove",
    "bin/test-tracker-exec-tracker",
    "bin/test-tracker-exec-tracker-helper",
    "bin/test-tracker-list",
    "bin/test-tracker-exec-lsf-tail",
    "bin/test-tracker-exec-lsf-interactive",
    "bin/test-tracker-exec-lsf-redirect"
  ],
  "LICENSE" => "perl",
  "NAME" => "TestTracker",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Cwd" => 0,
    "DBI" => 0,
    "Data::UUID" => 0,
    "File::Path" => 0,
    "File::Spec" => 0,
    "Getopt::Long" => 0,
    "IO::File" => 0,
    "IPC::Open3" => 0,
    "IPC::System::Simple" => 0,
    "List::MoreUtils" => 0,
    "List::Util" => 0,
    "POSIX" => 0,
    "Pod::Usage" => 0,
    "Symbol" => 0,
    "YAML" => 0,
    "autodie" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.014",
  "test" => {
    "TESTS" => "t/unit/TestTracker/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



