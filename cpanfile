requires 'DBI';
requires 'IPC::System::Simple';
requires 'List::MoreUtils';
requires 'YAML';

on 'test' => sub {
    requires 'DBD::SQLite';
};

on 'develop' => sub {
    requires 'Dist::Zilla';
    requires 'Dist::Zilla::Plugin::AutoPrereqs';
    requires 'Dist::Zilla::Plugin::Git::NextVersion';
    requires 'Dist::Zilla::PluginBundle::Basic';
};
