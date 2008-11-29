package DB::CouchDB::Schema::Edit;
use DB::CouchDB::Schema;
use Moose;
use Term::ReadLine;
use Pod::Usage;

has schema => (is => 'rw', isa => 'DB::CouchDB::Schema');
has term   => (is => 'ro', default => sub {
        return Term::ReadLine->new('CouchDB::Schema Editor');
    }
);
has commands => (is => 'rw', isa => 'HashRef');
has view => (is => 'rw');

sub BUILD {
    my $self = shift;
    my %commands = (
        'Select View' => { ord => 1, run => sub {
                my @views = keys %{$self->schema()->views()};
                my $view = $self->_select_from_list("Select a view:", @views);
            }
        },
        'Edit View' => {ord => 2, run => sub {
            }
        }
    );
    $self->commands(\%commands);
}

sub _select_from_list {
    my $self = shift;
    my $prompt = shift;
    my @list = @_;
    print $prompt, $/;
    my $counter = 0;
    for my $item (@list) {
        print $counter++ . " - " . $item, $/;
    };
    my $selection = shift;
    $self->get_response('Enter a number or name(partials will work): ', sub {
        my $request = shift;
        #print STDERR "the request was $request", $/;
        if ($request =~ /^\d$/) {
            $selection = $list[$request];
            #print STDERR "the selection was $selection", $/;
            return 1 if $selection;
        } else {
            if (my ($item) = grep {$_ =~ /$request/i } @list) {
                $selection = $item;
                #print STDERR "the selection was $selection", $/;
                return 1;
            }
        }
        return;
    });
    return $selection;
    
};

sub run {
    my $self = shift;
    if (!$self->schema()) {
        $self->connect();
    }
    $self->process_commands();
    $self->quit();
}

sub process_commands {
    my $self = shift;
    my $commands = $self->commands();
    my @coms = sort { $commands->{$a}->{ord} <=> $commands->{$b}->{ord} } 
        keys %{$self->commands()};
    my $command = $self->_select_from_list("please choose an action:", @coms);
    $self->commands()->{$command}->{run}->();
}

sub connect {
    my $self = shift;
    my $hostname;
    $self->get_response('Enter couchdb hostname: ', sub {
        $hostname = shift;
        if (!$hostname) {
            print STDERR "you must enter a hostname.";
            $self->quit();
            return;
        }
        return 1;
    }, 1);
    my $port;
    $self->get_response('Enter couchdb port[5984]: ', sub {
        $port = shift;
        $port = '5984' if (!$port);
    });
    my $db;
    my $dblist = DB::CouchDB->new(host => $hostname, port => $port)
        ->all_dbs();
    my $db_name = $self->_select_from_list('Select a Database', @$dblist);
    $self->schema(new DB::CouchDB::Schema->new(host => $hostname,
                                               port => $port,
                                               db   => $db_name
                                              ));
}

sub get_response {
    my $self = shift;
    my $prompt = shift;
    my $validator = shift;
    my $add_history = shift;
    print $/;
    my $response = $self->term()->readline($prompt);
    if (!$validator->($response)) {
        $self->get_response($prompt, $validator);
    } else {
        $self->term()->addhistory($response) if $add_history;
    }
}

sub quit {
    my $self = shift;
    $self->get_response('Quit?[y/N]: ', sub {
        my $quit = shift;
        if (lc($quit) eq 'y') {
            exit 0;
        } else {
            return 1;
        }
    });
}

1;
