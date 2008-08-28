package DB::CouchDB::Schema;
use DB::CouchDB;

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

sub load_schema_from_script {
    my $self = shift;
    my $script = shift;
    $self->{schema} = $self->{db}->json->decode($script);
    return $self;
}

sub load_schema_from_db {
    my $self = shift;
    my $db = $self->{db};
    #load our schema
    my $doc_list = $db->all_docs();
    my @schema;
    while ($docname = $doc_list->next_key() ) {
        my $doc = $db->get_doc($docname);
        #delete $doc->{_rev};
        push @schema, $doc;
    }
    $self->{schema} = \@schema;
    return $self;
}

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

sub dump {
    my $self = shift;
    my $db = $self->{db};
    my @schema = $self->_schema_no_revs();
    return $db->json->encode(\@schema)
}

sub push {
    my $self = shift;
    my $script = shift;
    my $db = $self->{db};
    for my $doc ( $self->_schema_no_revs() ) {
        $db->create_named_doc($doc, $doc->{_id});
    }
}

sub wipe {
    my $self = shift;
    my $db = $self->{db};
    my @schema = @{ $self->schema() };
    use YAML;
    for my $doc (@schema) {
        warn "Deleting: ".$doc->{_id}. " at revision: ".$doc->{_rev};
        warn Dump($db->delete_doc($doc->{_id}, $doc->{_rev}));
    }
}

1;
