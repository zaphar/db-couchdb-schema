use inc::Module::Install;

name 'DB-CouchDB';

requires 'JSON';
requires 'LWP::UserAgent';
requires 'URI';

all_from 'lib/DB/CouchDB.pm';

auto_install;
WriteAll;
