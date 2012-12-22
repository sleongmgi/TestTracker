package TestTracker::Config;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    $db_user
    $db_password
    $db_host
    $db_schema
    $db_name

    $filter_inc_regex

    $lsf_log_dir
);

# Database Configuration:
our $db_user = 'genome';
our $db_password = 'TGIlab';
our $db_host = 'gms-postgres';
our $db_schema = 'test_dependencies';
our $db_name = 'genome';

our $filter_inc_regex = qr{^lib/perl/Genome};

our $lsf_log_dir = '/gscmnt/sata848/info/jenkins/jobs/workspace';
