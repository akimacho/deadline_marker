#!/usr/bin/env perl
use Mojolicious::Lite;
use Encode qw/encode_utf8 decode_utf8/;
use FindBin;
use lib "$FindBin::Bin/lib/";
use MyApp::DB;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

get '/' => sub {
  my $c = shift;
	my $db = MyApp::DB->new({
		dsn => 'dbi:SQLite:dbname=test.db'
	});
	my $itr = $db->search('Deadline', {});
	$c->stash->{Deadline} = $itr;
  $c->render(template => 'index');
};

get '/account' => sub {
	my $c = shift;
	$c->render(template => 'account');
};

get '/account/new' => sub {
	my $c = shift;
	my $name = $c->req->param('name');
	my $event = $c->req->param('event');
	my $deadline = $c->req->param('deadline');
	my $db = MyApp::DB->new({
		dsn => 'dbi:SQLite:dbname=test.db'
	});
	$db->insert('Deadline', {
		name => $name,
		event => $event,
		deadline => $deadline,
		reg_date => '2015-4-13'
	});
	$c->stash->{name} = $name;
	$c->stash->{event} = $event;
	$c->stash->{deadline} = $deadline;
	$c->render(template => 'new');
};

helper mydecode_utf8 => sub {
	my ($self, $str) = @_;
	return decode_utf8($str);
};

app->secrets(['My very secret passphrase.']);

app->start;
