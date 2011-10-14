#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket;
use Redis;

our $sock;
our $redis = Redis->new;

sub redis() {	$redis->ping or $redis = Redis->new; $redis; }
sub rmpadding($) { $_[0] =~ s/(?:^[\r\n\s\f]+|[\r\n\s\f]+$)//g; $_[0]; }
sub pysplit { split(/\s+/, rmpadding $_[0]); }
sub parse($) {
		my $s = shift;
		my $prefix = '';
		my @trailing = ();
		my @args = ();

		return if $s eq '' || !defined $s;

		$s = rmpadding $s;

		($prefix, $s) = split(/ /, substr($s, 1), 2) if index($s, ':') == 0;

		if(index($s, ' :') != -1) {
				($s, @trailing) = split(/ :/, $s, 2);
				@args = pysplit($s);
				push @args, @trailing;
		} else {
				@args = pysplit($s);
		}

		my $command = shift @args;
		return (prefix => $prefix, command => $command, args => \@args);
}
sub msg {
		my ($cmd, @args) = @_;
		my $msg = uc($cmd)." ".join(' ',@args);
		print $sock "$msg\r\n";
		print "> $msg\n";
}
sub nick($) {
		my $n = shift;
		msg("nick",$n);
}
sub user($$$) {
		my ($l,$m,$r) = @_;
		msg("user",$l,$m,"*",":".$r);
}
sub privmsg($$) {
		my ($d, $m) = @_;
		msg("privmsg",$d,":".$m);
}
sub join_($) {
		my $c = shift;
		msg("join",$c);
}
sub pong($) {
		my $s = shift;
		msg("pong",$s)
}
sub adminp {
		my $u = shift;
		return 1 if $u =~ m[!~entel\@botters/entel$];
		0;
}
sub chanp {
		my $c = shift;
		return 1 if $c eq '#tankjet';
		0;
}
sub triggerp {
		my $s = shift;
		substr($s,0,1) eq '$';
}
sub parse_cmd {
		my $s = shift;
		$s = substr($s,1);
		my ($cmd, $rest) = split(/ /, $s, 2);
		return ($cmd, [split(/ /, $rest)]);
}
sub dispatch {
		my ($chan, $cmd, $args, $subs) = @_;

		if(exists $subs->{$cmd}) {
				my $r = $subs->{$cmd}->(@$args);
				privmsg $chan, $r if defined $r;
		}
}
sub handle_privmsg {
		my $m = shift;
		my ($chan, $user, $said) = ($m->{args}[0], $m->{prefix}, $m->{args}[1]);

		if(chanp($chan) && triggerp($said)) {
				my ($cmd, $args) = parse_cmd($said);

				if(adminp($user)) {
						# privelaged commands
						dispatch($chan, $cmd, $args, { set => sub { my ($k, @r) = @_; redis->set($k => join(' ', @r)); undef; },
										                       del => sub { redis->del($_[0]); undef; }}); # TODO see below
				} 
				# non-privelaged commands
				dispatch($chan, $cmd, $args, { get => sub { redis->get($_[0]); }}); # TODO pack those first three variables up to pass them to the dispatch function
		}
}

$sock = IO::Socket::INET->new(PeerAddr => 'irc.freenode.net',
															PeerPort => 6667,
															Proto    => 'tcp') or die "couldn't connect to the server";
$sock->autoflush(1);

nick "redirc";
user "redirc","8","redirc";
join_ "#tankjet";

while(<$sock>) { 
		my %m = parse $_;

		print "< $m{prefix} $m{command} ". join(' ', @{$m{args}})."\n";

		pong $m{args}[0]   if $m{command} eq 'PING' && $m{prefix} eq '';
	  handle_privmsg(\%m) if $m{command} eq 'PRIVMSG';
}
close $sock;
