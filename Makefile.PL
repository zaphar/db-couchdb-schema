use inc::Module::Install;

name 'DB-CouchDB';

requires 'JSON';
requires 'LWP::UserAgent';
requires 'URI';

all_from 'lib/DB/CouchDB.pm';

install_script 'couch_schema_tool.pl';

auto_install;
WriteAll;
