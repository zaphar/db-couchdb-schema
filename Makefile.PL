use inc::Module::Install;

name 'DB-CouchDB-Schema';

requires 'JSON';
requires 'Getopt::Long';
requires 'LWP::UserAgent';
requires 'Moose'            => '0.57';
requires 'Carp';
requires 'URI';
requires 'Pod::Usage';

build_requires 'Test::MockObject';

all_from 'lib/DB/CouchDB/Schema.pm';

install_script 'couch_schema_tool.pl';

auto_install;
WriteAll;
