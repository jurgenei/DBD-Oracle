#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

use DBI qw(:sql_types);
unshift @INC ,'t';
require 'nchar_test_lib.pl';
use Data::Printer;

my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

my $dbh = DBI->connect( $dsn, $dbuser, '',  {
    PrintError => 0, FetchHashKeyName =>'NAME_lc'});

plan skip_all => "unable to connect to Oracle database" if not $dbh;

my $v = 12;
my $ora_server_version = $dbh->func("ora_server_version");
my $ora_client_version = DBD::Oracle::ORA_OCI();
my $less12_2 = $ora_client_version < $v || $ora_server_version->[0] < $v;

plan skip_all => "Oracle client=$ora_client_version/database=$ora_server_version->[0] version less than $v" if $less12_2;

plan tests => 9;

my $q =<<SQL
DECLARE
  l1 SYS_REFCURSOR;
  l2 SYS_REFCURSOR;
  l3 SYS_REFCURSOR;
BEGIN
  OPEN l1 FOR SELECT 'aap','noot','mies' FROM DUAL;
  DBMS_SQL.RETURN_RESULT(l1);
  OPEN l2 FOR SELECT 'foo','bar' FROM DUAL
              UNION
              SELECT 'nut','meg' FROM DUAL;
  DBMS_SQL.RETURN_RESULT(l2);
  OPEN l3 FOR SELECT 'cat','dog','hamster' FROM DUAL;
  DBMS_SQL.RETURN_RESULT(l3);
END;
SQL
;
my $expected_r = [
    [[qw(aap noot mies)]],
    [[qw(foo bar)],
     [qw(nut meg)]],
    [[qw(cat dog hamster)]],
  ];

my $s = $dbh->prepare($q);
ok($s, 'implicit prep ok');
ok($s->execute,'implicit exec ok');

my @l;
while($s->ora_next_result) {
   my $a = $s->fetchall_arrayref;
   push @l,$a;
};
is_deeply(\@l, $expected_r,'implicit fetched results');

my $q2 =<<SQL
SELECT 'aap' FROM dual
SQL
;
$s = $dbh->prepare($q2);
ok($s->execute,'explicit exec ok');
my $i = $s->ora_next_result;
ok(!$i,'explicit ora_next_result empty');
my $a = $s->fetchall_arrayref;
is_deeply($a,[[qw(aap)]],'explicit select');

# sybase behavior

$dbh -> {ora_implicit_prefetch} = 1;
my $s2 = $dbh->prepare($q);
ok($s2, 'prefetch implicit prep ok');
ok($s2->execute,'prefetch implicit exec ok');
my @l2;
do {
   my $a = $s2->fetchall_arrayref;
   push @l2,$a;
}
while($s2->{syb_more_results});

is_deeply(\@l2, $expected_r,'prefetch implicit results');

$dbh->disconnect;


