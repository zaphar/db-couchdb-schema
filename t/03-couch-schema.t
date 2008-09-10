use Test::More;

plan tests => 2;

my $module = 'DB::CouchDB::Schema';

use_ok($module);
can_ok($module, qw/_mk_view_accessor load_schema_from_db
                   load_schema_from_script
                   /);

my $db = $module->new();

$db->_mk_view_accessor( { _id => '_design/foo', 
                          views => {bar => '"blah"',
                                    boo => '"Ahh!!"'
                                   }
                         }
                      );

can_ok($db, 'foo_bar', 'foo_boo');

$db->views()->{'foo_bar'} = sub { return 'fubar'; };

is($db->foo_bar(), 'fubar', 'the created method delegates properly');
