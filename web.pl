#!/usr/bin/perl
use Redis;
use URI::Encode 'uri_encode';

my $r = Redis->new;

print qq{Content-type: text/html\n\n<html><body><table width="100%" border="1"><tr><td><b>key</b></td><td><b>value</b></td></tr>};

foreach my $k (sort $r->keys('*')) {	
		my $v = $r->get($k);
		$v = '<a href="'.uri_encode($v).qq[" target="_blank">$v</a>] if $v =~ m#^[^:]+://#;
		print "<tr><td>$k</td><td>$v</td></tr>"; 
}
print "</table></body></html>";
