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

helper mydecode_utf8 => sub {
	my ($self, $str) = @_;
	return decode_utf8($str);
};

app->start;
