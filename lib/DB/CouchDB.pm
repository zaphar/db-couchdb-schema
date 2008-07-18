package DB::CouchDB;

use warnings;
use strict;
use JSON -convert_blessed_universally;
use LWP::UserAgent;
use URI;

$DB::CouchDB::VERSION = 0.1;

=head1 NAME

    DB::CouchDB - An alternative to the Net::CouchDb module

=head1 RATIONALE

Net::CouchDb uses JSON::Any which means handling blessed objects is difficult.
Since the JSON serializer could be any one of a number of modules setting the correct
parameters is difficult and in fact the Net::CouchDb module doesn't allow for this.
DB::CouchDB is intended to allow the modifying the functionality of the serializer
for blessed objects and so on.

DB::CouchDB makes no assumptions about what you will be sending to your db. You don't
have to create special document objects to submit. It will make correct assumptions
as much as possible and allow you to override them as much as possible.

=cut

sub new{
    my $class = shift;
    my %opts = @_;
    $opts{port} = 5984
        if (!exists $opts{port});
    my $obj = {%opts};
    $obj->{json} = JSON->new();
    #my $uri = URI->new('http://'.$opts{host}.':'.$opts{port});
    #$obj->{uri} = $uri;
    return bless $obj, $class; 
}

sub all_dbs {
    my $self = shift;
    return $self->_call(GET => $self->_uri_all_dbs()); 
}

sub db_info {
    my $self = shift;
    my $db = shift;
    return $self->_call(GET => $self->_uri_db($db));
}

sub create_db {
    my $self = shift;
    my $db = shift;
    return $self->_call(PUT => $self->_uri_db($db));
}

sub delete_db {
    my $self = shift;
    my $db = shift;
    return $self->_call(DELETE => $self->_uri_db($db));
}

sub create_doc {
    my $self = shift;
    my $db = shift;
    my $doc = shift;
    my $jdoc = $self->json()->encode($doc);
    return $self->_call(POST => $self->_uri_db($db), $jdoc);
}

sub create_named_doc {
    my $self = shift;
    my $db = shift;
    my $doc = shift;
    my $name = shift;
    my $jdoc = $self->json()->encode($doc);
    return $self->_call(PUT => $self->_uri_db_doc($db, $name), $jdoc);
}


sub update_doc {
    my $self = shift;
    my $db   = shift;
    my $name = shift;
    my $doc  = shift;
    my $jdoc = $self->json()->encode($doc);
    return $self->_call(PUT => $self->_uri_db_doc($db, $name), $jdoc);
}

sub delete_doc {
    my $self = shift;
    my $db = shift;
    my $doc = shift;
    my $rev = shift;
    my $uri = $self->_uri_db_doc($db, $doc);
    $uri->query('rev='.$rev);
    return $self->_call(DELETE => $uri);
}

sub get_doc {
    my $self = shift;
    my $db = shift;
    my $doc = shift;
    return $self->_call(GET => $self->_uri_db_doc($db, $doc));
}

sub view {
    my $self = shift;
    my $db = shift;
    my $view = shift;
    return $self->_call(GET => $self->_uri_db_view($db, $view));
}

sub json {
    my $self = shift;
    return $self->{json};
}

sub handle_blessed {
    my $self = shift;
    my $set  = shift;

    my $json = $self->json();
    if ($set) {
        $json->allow_blessed(1);
        $json->convert_blessed(1);
    } else {
        $json->allow_blessed(0);
        $json->convert_blessed(0);
    }
    return $self;
}

sub uri {
    my $self = shift;
    my $u = URI->new();
    $u->scheme("http");
    $u->host($self->{host}.':'.$self->{port});
    return $u;
}

sub _uri_all_dbs {
    my $self = shift;
    my $uri = $self->uri();
    $uri->path('/_all_dbs');
    return $uri;
}

sub _uri_db {
    my $self = shift;
    my $db = shift;
    my $uri = $self->uri();
    $uri->path('/'.$db);
    return $uri;
}

sub _uri_db_docs {
    my $self = shift;
    my $db = shift;
    my $uri = $self->uri();
    $uri->path('/'.$db.'/_all_docs');
    return $uri;
}

sub _uri_db_doc {
    my $self = shift;
    my $db = shift;
    my $doc = shift;
    my $uri = $self->uri();
    $uri->path('/'.$db.'/'.$doc);
    return $uri;
}

sub _uri_db_bulk_doc {
    my $self = shift;
    my $db = shift;
    my $uri = $self->uri();
    $uri->path('/'.$db.'/_bulk_docs');
    return $uri;
}

sub _uri_db_view {
    my $self = shift;
    my $db = shift;
    my $view = shift;
    my $uri = $self->uri();
    $uri->path('/'.$db.'/_view/'.$view);
    return $uri;
}

sub _call {
    my $self    = shift;
    my $method  = shift;
    my $uri     = shift;
    my $content = shift;

    my $req     = HTTP::Request->new($method, $uri);
    $req->content($content);
         
    my $ua = LWP::UserAgent->new();
    my $response = $ua->request($req)->content();
    my $decoded = $self->json()->decode($response);
    return $decoded;
}

=head1 AUTHOR

Jeremy Wall <jeremy@marzhillstudios.com>

=head1 TODO

- add view creation helpers
- add more robust error handling
- documentation

=cut

1;
