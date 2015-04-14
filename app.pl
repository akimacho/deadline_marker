#!/usr/bin/env perl
use Mojolicious::Lite;
use Encode qw/encode_utf8 decode_utf8/;
use FindBin;
use lib "$FindBin::Bin/lib/";
use Net::Twitter::Lite;
use MyApp::DB;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

my $config = plugin('Config');

my $nt = Net::Twitter::Lite->new(
	apiurl => 'http://api.twitter.com/1.1',
	searchapiurl => 'http://api.twitter.com/1.1/search',
	search_trends_api_url => 'http://api.twitter.com/1.1',
	lists_api_url => 'http://api.twitter.com/1.1',
	consumer_key => $config->{consumer_key},
	consumer_secret => $config->{consumer_secret},
	legacy_lists_api => 1,
	ssl => 1,
);

my $db = MyApp::DB->new({
	dsn => 'dbi:SQLite:dbname=test.db'
});

get '/' => sub {
  my $c = shift;
	my $itr = $db->search('Deadline', {});
	$c->stash->{Deadline} = $itr;
  $c->render(template => 'index');
};

get '/login' => sub {
	my $c = shift;
	my $url = $nt->get_authorization_url(
		callback => $c->req->url->base . '/callback'
	);
	$c->session(token => $nt->request_token);
	$c->session(token_secret => $nt->request_token_secret);
	$c->redirect_to($url);
};

get '/logout' => sub {
	my $c = shift;
	$c->session(expires => 1);
	$c->redirect_to('/');
};

get '/callback' => sub {
	my $c = shift;
	unless ($c->req->param('denied')) {
		$nt->request_token($c->session('token'));
		$nt->request_token_secret($c->session('token_secret'));
		my $verifier = $c->req->param('oauth_verifier');
		my ($access_token, $access_token_secret, $user_id, $screen_name)
			= $nt->request_access_token(verifier => $verifier);
		$c->session(access_token => $access_token);
		$c->session(access_token_secret => $access_token_secret);
		$c->session(screen_name => $screen_name);
		$c->redirect_to('/account');
	}
	else {
		$c->redirect_to('/');
	}
};

get '/account' => sub {
	my $c = shift;
	if($c->session('access_token')) {
		$nt->access_token($c->session('access_token'));
		$nt->access_token_secret($c->session('access_token_secret'));
	}
	else {
		$c->redirect_to('/');
	}
	$c->stash->{screen_name} = $c->session('screen_name') || '名無し';
	$c->render(template => 'account');
};

get '/account/new' => sub {
	my $c = shift;
	my $name = $c->req->param('name');
	my $event = $c->req->param('event');
	my $deadline = $c->req->param('deadline');

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

app->sessions->secure(1);
app->secrets(['My very secret passphrase.']);
app->start;
