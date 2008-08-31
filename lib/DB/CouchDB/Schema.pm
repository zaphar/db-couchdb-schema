package DB::CouchDB::Schema;
use DB::CouchDB;

our $VERSION = '0.2.1';

=head1 NAME

    DB::CouchDB::Schema - A Schema driven CouchDB module

=head1 VERSION

0.2.1

=head1 RATIONALE

After working with several of the CouchDB modules already in CPAN I found
myself dissatisfied with them. DB::CouchDB::Schema is intended to approach the
CouchDB Workflow from the standpoint of the schema. It provides tools for dumping
and restoring the views that define your schema and for querying the views in your
schema easily.

=head1 METHODS

=head2 new(%opts)

    my $schema = DB::CouchDB::Schema->new(host => $hostname,
                                          port => $db_port, # optional defaults to 5984
                                          db   => $databse_name);

Constructor for a CouchDB Schema.

=cut

sub new {
    my $self = shift;
    my $db = DB::CouchDB->new(@_);
    $db->handle_blessed(1);
    my $obj = bless {}, $self; 
    $obj->{db} = $db;
    my $doc_list = $db->all_docs();
    my $schema = $obj->load_schema_from_db();
    return $obj;
}

=head2 load_schema_from_script($script)

loads a CouchDB Schema from a json script file. This is sort of like the DDL
in a SQL DB only its essentially just a list of _design/* documents for the CouchDB

=cut

sub load_schema_from_script {
    my $self = shift;
    my $script = shift;
    $self->{schema} = $self->{db}->json->decode($script);
    return $self;
}

=head2 load_schema_from_db()

Loads a CouchDB Schema from the Database on the server. this can later be dumped
to a file and pushed to a database using load_schema_from_script.

This method gets called for you during object construction so that you will have
a current look at the CouchDB Schema stored in your object.

=cut

sub load_schema_from_db {
    my $self = shift;
    my $db = $self->{db};
    #load our schema
    my $doc_list = $db->all_docs({startkey => '"_design/"',
                                  endkey   => '"_design/ZZZZZ"'});
    my @schema;
    while ($docname = $doc_list->next_key() ) {
        my $doc = $db->get_doc($docname);
        $self->_mk_view_accessor($doc);
        push @schema, $doc;
    }
    $self->{schema} = \@schema;
    return $self;
}

sub _mk_view_accessor {
    my $self = shift;
    my $doc = shift;
    my $id = $doc->{_id};
    return unless $id =~  /^_design/;
    my ($design) = $id =~ /^_design\/(.+)/;
    my $views = $doc->{views};
    for my $view (keys %$views) {
        my $method = $design."_".$view;
        $self->{views}{$method} = sub {
            my $args = shift;
            return $self->{db}->view($design."/$view", $args);
        };
    }
}

=head2 schema

Returns the database schema as an arrayref of _design/ docs serialized to perl
objects. You can update you schema by modifying this object if you know what
you are doing. Then push the modifications to your database.

=cut

sub schema {
    return shift->{schema};
}

sub _schema_no_revs {
    my $self = shift;
    my @schema;
    for my $doc (@{ $self->schema() }) {
        my %newdoc = %$doc;
        delete $newdoc{_rev};
        push @schema, \%newdoc;
    }
    return @schema;
}

=head2 dump($pretty)

Returns the database schema as a json string.

=cut

sub dump {
    my $self = shift;
    my $pretty = shift;
    my $db = $self->{db};
    $db->json->pretty([$pretty]);
    my @schema = $self->_schema_no_revs();
    my $script = $db->json->encode(\@schema);
    $db->json->pretty([undef]);
    return $script;
}

=head2 dump($pretty)

Pushes the current schema stored in the object to the database. Used in combination with load_schema_from_script
you can restore or create databse schemas from a json defintion file.

If $pretty is true then the string will be pretty printed.

=cut

sub push {
    my $self = shift;
    my $script = shift;
    my $db = $self->{db};
    $self->wipe();
    for my $doc ( $self->_schema_no_revs() ) {
        $db->create_named_doc($doc, $doc->{_id});
    }
    $self->load_schema_from_db();
    return $self;
}

=head2 get($doc)

=cut

sub get {
    my $self = shift;
    my $name = shift;
    return $self->{db}->get_doc($name);
}

=head2 wipe

Wipes the schema from the database. Only deletes the views not data and
only deletes views it knows about from either of the load_schema_from_* methods.

=cut

sub wipe {
    my $self = shift;
    my $db = $self->{db};
    my @schema = @{ $self->schema() };
    for my $doc (@schema) {
        $db->delete_doc($doc->{_id}, $doc->{_rev});
    }
}

=head1 ACCESSORS

When DB::CouchDB objects are new'ed up they create accessors for the views defined
in the Database. Calling C<$schema->view_name(\%view_args)> will return you the data
for the views. See L<DB::CouchDB> view method for more information on the args for a view.

=cut

sub AUTOLOAD {
    my ($package, $call) = $AUTOLOAD =~ /^(.+)::(.+)$/;
    my $self = shift;
    if ($package eq 'DB::CouchDB::Schema') {
        if ( exists $self->{views}{$call}) {
            return $self->{views}{$call}->(@_);
        }
    }
}

1;
