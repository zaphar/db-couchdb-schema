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
    my $pretty = shift;
    my $db = $self->{db};
    $db->json->pretty([$pretty]);
    my @schema = $self->_schema_no_revs();
    my $script = $db->json->encode(\@schema);
    $db->json->pretty([undef]);
    return $script;
}

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

sub get {
    my $self = shift;
    my $name = shift;
    return $self->{db}->get_doc($name);
}

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
