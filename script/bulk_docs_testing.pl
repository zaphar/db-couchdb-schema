#!/usr/bin/perl

use strict;
use warnings;
use DB::CouchDB;
use Data::Dumper;
use Carp;

my $rs;
my $db = DB::CouchDB->new(
    host     => '127.0.0.1',
    db       => 'aak',
    user     => 'james',
    password => '9makJ3',
);
my $dbs = $db->all_dbs();
my ($aak) = grep { /aak/sm } @{$dbs};
if ( !$aak ) {
  $rs = $db->create_db();
  if ( $rs->err ) {
    croak $rs->errstr;
  }
}

# test bulk docs
my $docs = [];
push @{$docs},    {
        host => '127.0.0.1',
        db   => 'aak',
        user => 'james',
    };

push @{$docs},    {
        host => '127.0.0.1',
        db   => 'aak',
        user => 'james',
    };

push @{$docs},    {
        host => '127.0.0.1',
        db   => 'aak',
        user => 'james',
    };

push @{$docs},    {
        host => '127.0.0.1',
        db   => 'aak',
        user => 'james',
    };

my $array = $db->bulk_docs($docs);
carp Dumper $array;


my $iter   = $db->all_docs();
while ( my $doc = $iter->next() ) {
  my %result = %{$doc};
  carp Dumper \%result;
}

$rs = $db->delete_db();

1;

__END__

