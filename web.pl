#!/usr/bin/perl
use Redis;

my $r = Redis->new;
print qq{Content-type: text/html\n\n<html><body><table width="100%" border="1"><tr><td><b>key</b></td><td><b>value</b></td></tr>};
foreach my $k ($r->keys('*')) {	my $v = $r->get($k); print "<tr><td>$k</td><td>$v</td></tr>"; }
print "</table></body></html>";
