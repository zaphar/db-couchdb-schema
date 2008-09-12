package Test::Mock::CouchDBSchema;
use DB::CouchDB::Schema;
use Moose;
use Moose::Util::TypeConstraints;
use Carp;

=head1 NAME

Test::Mock::CouchDBSchema - A module to make mocking a DB::CouchDB::Schema easier

=head1 SYNOPSIS

=cut

subtype mock_hash => as 'Hash' =>
    where sub {
        my $hash = $_;
        return 1 if (exists $$hash{name} && exists $$hash{code});
        return;
    };

has mocked_views => ( is => 'rw', isa => 'HashRef[CodeRef]', required => 1,
                     default => sub { return {}; } );

has mocked_docs => ( is => 'rw', isa => 'HashRef[CodeRef]', required => 1,
                    default => sub { return {}; } );

has mock_schema => ( is => 'rw', isa => 'ArrayRef', required => 1,
                    default => sub { return []; } );
sub BUILD {
    my $self = shift;
    #when we have loaded this we want to prevent schema loads
    my $mock_schema_method = sub {
        my $otherself = shift;
        $otherself->schema($self->(mock_schema));
        return $otherself;
    };

    DB::CouchDB::Schema->meta
        ->add_around_method_modifier(
            'load_schema_from_db' => $fake_schema_method);

}

sub mock_view {
    my $self = shift;
    my $view_name = shift;
    my $view_rows = shift;
    
    my $method_body = sub {
        return DB::CouchDB::Iter->new( { rows => $view_rows } );
    };
    
    my $mocked = $self->mocked_views();
    $mocked->{$view_name} = $method_body;
    $self->mocked_views($mocked);
    
    DB::CouchDB::Schema->meta->add_method($view_name, $method_body);
    
    return $self;
}

sub unmock_view {
    my $self = shift;
    my $view_name = shift;
    croak "request to unmock $view_name when it is not mocked!!"
        if !defined $self->mocked_views()->{$view_name};
    delete $self->mocked_views()->{$view_name}; 
    DB::CouchDB::Schema->meta->remove_method($view_name);
    return $self;
}

sub unmock_all_views {
    my $self = shift;
    my @mocks = keys %{ $self->mocked_views() };
    
    for my $mocked ( @mocks ) {
        $self->unmock_view($mocked);
    }
}

sub mock_doc {

}

1;
