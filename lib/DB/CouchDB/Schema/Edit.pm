package DB::CouchDB::Schema::Edit;
use DB::CouchDB::Schema;
use Moose;
use Term::ReadLine;
use File::Temp qw/tempfile tempdir/;
use Pod::Usage;

has schema => (is => 'rw', isa => 'DB::CouchDB::Schema');
has term   => (is => 'ro', default => sub {
        return Term::ReadLine->new('CouchDB::Schema Editor');
    }
);
has commands => (is => 'rw', isa => 'HashRef');
has view => (is => 'rw', isa => 'Str');
has func => (is => 'rw', isa => 'Str');

sub BUILD {
    my $self = shift;
    my %commands = (
        'Select Design Doc' => { ord => 1, run => sub {
                my @views; 
                my $designnames = $self->schema()->get_views();
                while (my $designname = $designnames->next_key()) {
                    my $viewdoc = $self->schema()->get($designname);
                    #for my $viewname (keys %{$viewdoc->{views}}) {
                    #    push @views, $designname."/".$viewname;
                    #}
                    push @views, $designname;
                }
                my $view = $self->_select_from_list("Select a view:", @views);
                $self->view($view);
                $self->{func} = undef;
            }
        },
        'Select View Func' => {ord => 2, run => sub {
                if ($self->view()) {
                    my @funcs;
                    my $designdoc = $self->schema()->get($self->view());
                    for my $fname (keys %{$designdoc->{views}}) {
                        push @funcs, $fname;
                    }
                    my $funcname = $self->_select_from_list(
                        "Select a view function" => @funcs
                    );
                    $self->func($funcname);
                } else {
                    print STDERR "You have to select a Design Doc first",$/;
                }
            }
        },
        'Edit View Func' => {ord => 3, run => sub {
                my $viewobj = $self->schema->get($self->view());
                my $viewfunc = $viewobj->{views}->{$self->func};
                use YAML;
                my $map = $viewfunc->{map}; 
                my $reduce = $viewfunc->{reduce};
                my $sel = $self->_select_from_list('Select:', 'map', 'reduce');
                my ($fh, $name) = tempfile('tempXXXX', SUFFIX => '.js');
                print STDERR $name, $/;
                my $editor = $ENV{EDITOR} || 'vim';
                if ($sel eq 'map') {
                    print $fh $map;
                    close $fh;
                    system("$editor $name");
                    open $fh, $name;
                    {
                        local $/;
                        $viewfunc->{map} = <$fh>;
                    }
                } else {
                    print $fh $reduce;
                    close $fh;
                    system("$editor $name");
                    open $fh, $name;
                    {
                        local $/;
                        $viewfunc->{reduce} = <$fh>;
                    }
                }
                my $result = $self->schema()->server->update_doc(
                    $viewobj->{_id} => $viewobj
                );
                #use YAML;
                #print STDERR Dump($result);
            }
        },
        'Quit' => { ord => 100, run => sub {
                $self->quit();
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
                $self->term()->addhistory($item);
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

sub show_meta {
    my $self = shift;
    print "Editing: ".
        $self->schema()->server()->host() . "/" . 
        $self->schema()->server()->db();
    print $/;
    if ($self->view) {
        print "Selected View: ". $self->view(),$/;
    }
    if ($self->func) {
        print "Selected View Func: ". $self->func(),$/;
    }
    print $/;
}

sub process_commands {
    my $self = shift;
    my $commands = $self->commands();
    my @coms = sort { $commands->{$a}->{ord} <=> $commands->{$b}->{ord} } 
        keys %{$self->commands()};
    while (1) {
        $self->show_meta();
        my $command = $self->_select_from_list("please choose an action:", @coms);
        $self->commands()->{$command}->{run}->();
    }
}

sub connect {
    my $self = shift;
    my $hostname;
    $self->get_response('Enter couchdb host[localhost]: ', sub {
        $hostname = shift;
        if (!$hostname) {
            $hostname = 'localhost';
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
