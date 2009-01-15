use Test::More;
use Test::Moose;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use warnings;
use strict;

plan tests => 24;

my $module = 'DB::CouchDB::Schema';

use_ok($module);
can_ok($module, qw/_mk_view_accessor load_schema_from_db
                   load_schema_from_script BUILD
                   /);

has_attribute_ok($module, 'server');

# test BUILD
{
    my $mock = mock_couchdb();
    my $db = $module->new();
    ok(!$db->server(), 'the server attribute is not set');
    $db = $module->new(host => 'fakehost', db => 'fakedatabase');
    ok($db->server(), 'the server attribute is set');
    is($db->server->handle_blessed(), 1, 'handle_blessed has been set to one');

}

# test view accessor creation
{
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
    
    can_ok($module, 'dump_whole_db');
}

#test doc creation
{
    my $mocker = mock_couchdb();
    $mocker->mock(create_named_doc => sub {
        my $self = shift;
        my $doc = shift;
        my $name = shift;
        return DB::CouchDB::Result->new({ _id => $name, %$doc });
    });
    $mocker->mock(create_doc => sub {
        my $self = shift;
        my $doc = shift;
        return DB::CouchDB::Result->new({ _id => 'adoc', %$doc });
    });

    can_ok($module, 'create_doc');
    my $db = $module->new(host => 'fakehost', db => 'database');
    
    my $response = $db->create_doc( id => 'somedoc', doc => { foo => 'baz' } );
    is($response->{_id}, 'somedoc', 'create_doc with an id works');
    is($response->{foo}, 'baz', 'create_doc with an id has the doc attributes');

    my $response2 = $db->create_doc( doc => { foo => 'bar' } );
    is($response2->{_id}, 'adoc', 'create_doc without an id works');
    is($response2->{foo}, 'bar', 'create_doc without an id has the doc attributes');
    
    can_ok($module, 'create_new_db');
    $mocker->mock(create_db => sub {
            return DB::CouchDB::Result->new( { foo => 'bar' } );
        });

    throws_ok { $db->create_new_db() }
        qr/Must provide a db to create/,
        'not passing db => name to the creation method throws an error';
    lives_ok { $db->create_new_db( db => 'my_db') }
        'passing db => name succeeds';
    my $new_db = $db->create_new_db( db => 'my_db');
    ok($new_db != $db, 'our new_db is a different one from our old db');
    is($new_db->server->host, $db->server->host, 
        'the host is the same for both');
    is($new_db->server->port, $db->server->port, 
        'the port is the same for both');
    is($new_db->server->db, 'my_db', 
        'the db is my_db');
    $mocker->mock(create_db => sub {
            return DB::CouchDB::Result->new( { error => 'bar', reason => 'baz' } );
        });
    throws_ok { $db->create_new_db(db => 'my_db') }
        qr/Failed to create the DB my_db: baz/,
        'Couch Error results in an exception';

}

#test delete_doc
{
    my $mocker = mock_couchdb();
    $mocker->mock(delete_doc => sub {
            my $self = shift;
            my $name = shift;
            my $rev = shift;
            return DB::CouchDB::Result->new({ foo => 'bar' });
        });
    my $db = $module->new(host => 'fakehost', database => 'database');
    my $result = $db->delete_doc({_id => "some doc", _rev => '12gh587'});
    is($result->{foo}, 'bar', 'the result came back ok');
}

#test update_doc
{
    my $mocker = mock_couchdb();
    $mocker->mock(update_doc => sub {
            my $self = shift;
            my $doc = shift;
            return DB::CouchDB::Result->new({ foo => 'bar' });
        });
    my $db = $module->new(host => 'fakehost', database => 'database');
    my $result = $db->update_doc({_id => 'foobar', _rev => '9hg2ul5k'});
    is($result->{foo}, 'bar', 'the result came back ok');
}

## fixtures

sub mock_couchdb {
    my $mock = Test::MockModule->new('DB::CouchDB');
    $mock->mock('new' => sub { 
            my $class = shift;
            my %hash = @_;
            $hash{port} = 5984;
            $hash{db} = 'database' if !defined $hash{db};
            return bless \%hash, $class;
        });
    $mock->mock(handle_blessed => sub {
            my $self = shift;
            my $arg = shift;
            $self->{handle_blessed} = $arg if defined $arg;
            return $self->{handle_blessed};
        });
    $mock->mock(load_schema_from_db => sub { });
    return $mock;
}
