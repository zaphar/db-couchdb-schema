use inc::Module::Install;

name 'DB-CouchDB-Schema';

requires 'JSON';
requires 'Getopt::Long';
requires 'LWP::UserAgent';
requires 'URI';

all_from 'lib/DB/CouchDB/Schema.pm';

install_script 'couch_schema_tool.pl';

auto_install;
WriteAll;
