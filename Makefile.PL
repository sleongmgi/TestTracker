
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Track Perl module and test relationship so you can guess what are the best tests to run.",
  "AUTHOR" => "dmorton and nnutter",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "TestTracker",
  "EXE_FILES" => [
    "bin/test-tracker",
    "bin/test-tracker-list",
    "bin/test-tracker-prove",
    "bin/test-tracker-exec-lsf"
  ],
  "LICENSE" => "perl",
  "NAME" => "TestTracker",
  "PREREQ_PM" => {
    "Carp" => 0,
    "DBI" => 0,
    "Data::UUID" => 0,
    "Exporter" => 0,
    "File::Path" => 0,
    "File::Spec" => 0,
    "Getopt::Long" => 0,
    "IO::File" => 0,
    "IPC::System::Simple" => 0,
    "List::MoreUtils" => 0,
    "Pod::Usage" => 0,
    "YAML" => 0,
    "autodie" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.003",
  "test" => {
    "TESTS" => ""
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



