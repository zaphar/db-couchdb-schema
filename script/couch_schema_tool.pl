#!perl
use DB::CouchDB::Schema;
use Getopt::Long;

#TODO(jwall): Write POD and convert useage to do pod2useage
my ($dump,$load,$file,$help,
    $database,$host,$port,$dsn,
    $backup, $restore,
   );

my $opts = GetOptions ("dump" => \$dump,
                       "load" => \$load,
                       "file=s" => \$file,
                       "help"   => \$help,
                       "db=s"     => \$database,
                       "host=s"   => \$host,
                       "port=i"   => \$port,
                       "backup"    => \$backup,
                       "restore"    => \$restore,
                      );

sub useage {
    print $/;
    print "couch_schema_tool.pl --help # print this useage", $/, $/;
    print "# dump the schema to filename", $/;
    print "couch_schema_tool.pl --db=name --host=hostname [--port=<port>] \\
    --dump --file=filename ", $/, $/;;
    print "# load the schema from the filename", $/;
    print "couch_schema_tool.pl --db=name --host=hostname [--port=<port>] \\
    --load --file=filename ", $/, $/;;
    print "# backup the database to this filename", $/;
    print "couch_schema_tool.pl --db=name --host=hostname [--port=<port>] \\
    --backup  --file=filename ", $/, $/;;
    print "# restore the database from this filename", $/;
    print "couch_schema_tool.pl --db=name --host=hostname [--port=<port>] \\
    --restore  --file=filename ", $/, $/;;
}

if ( $help ) {
    useage();
    exit 0;
}

if ($database && $host) {
    my %dbargs = (db     => $database,
                  host   => $host);
    $dbargs{port} = $port
        if $port;
    my $db = DB::CouchDB::Schema->new(%dbargs);
    
    if ($dump && $file) {
        open my $fh, '>', $file or die $!;
        my $script = $db->dump(1);
        print $fh $script;
        close $fh;
        exit 0;
    } elsif ($load && $file) {
        open my $fh, $file or die $!;
        local $/;
        $script = <$fh>;
        print "loading schema: ", $/, $script;
        $db->wipe();
        $db->load_schema_from_script($script);
        $db->push();
        close $fh;
        exit 0;
    } elsif ($backup && $file) {
        # no the backup and restore code
        open my $fh, '>', $file or die $!;
        my $script = $db->dump_whole_db();
        print $fh $script;
        close $fh;
        exit 0;
    } elsif ($restore && $file) {
        # no the backup and restore code
        open my $fh, $file or die $!;
        local $/;
        $script = <$fh>;
        print "loading data: ", $/, $script;
        $db->wipe();
        $db->push_from_script($script);
        close $fh;
        exit 0;
    } else {
        print "Did not understand options!! did you specify one of", $/,
        "--dump, --load, --backup, or --restore with a --file?", $/;
        useage();
        exit 1;
    }
} else {
    print "Did not understand options!! Must have a db and a hostname", $/;
    useage();
    exit 1;
}

