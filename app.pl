#!/usr/bin/env perl
use Mojolicious::Lite;
use Encode qw/encode_utf8 decode_utf8/;
use FindBin;
use lib "$FindBin::Bin/lib/";
use Net::Twitter::Lite;
use Time::Piece;
use MyApp::DB;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

my $config = plugin('Config');

my $nt = Net::Twitter::Lite->new(
	apiurl								=> 'http://api.twitter.com/1.1',
	searchapiurl					=> 'http://api.twitter.com/1.1/search',
	search_trends_api_url => 'http://api.twitter.com/1.1',
	lists_api_url					=> 'http://api.twitter.com/1.1',
	consumer_key					=> $config->{consumer_key},
	consumer_secret				=> $config->{consumer_secret},
	legacy_lists_api			=> 1,
	ssl										=> 1,
);

my $db = MyApp::DB->new({dsn => 'dbi:SQLite:dbname=test.db'});

get '/' => sub {
  my $c = shift;
	my $itr = $db->search('Deadline', {});
	$c->stash->{Deadline} = $itr;
  $c->render(template => 'index');
};

get '/login' => sub {
	my $c = shift;
	my $url = $nt->get_authorization_url(callback => $c->req->url->base . '/callback');
	$c->session(token => $nt->request_token);
	$c->session(token_secret => $nt->request_token_secret);
	$c->redirect_to($url);
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

get '/admin' => sub {
	my $c = shift;
	my $usr = $c->req->param('usr') || '';
	my $pwd = $c->req->param('pwd') || '';
	if (decode_utf8($usr) eq decode_utf8($config->{usr})
				 && decode_utf8($pwd) eq decode_utf8($config->{pwd})) {
		$c->session(admin => 1);
		my $itr = $db->search('Deadline', {});
		$c->stash->{Deadline} = $itr;
		$c->render(template => 'admin');
	}
	else {
		$c->session(admin => 0);
		$c->redirect_to('/');
	}
};

get '/admin/del' => sub {
	my $c = shift;
	if ($c->session('admin')) {
		my $num = $c->req->param('del');
		$db->delete('Deadline', {id => $num});
  }
	$c->redirect_to('/admin');
};

get '/logout' => sub {
	my $c = shift;
	$c->session(expires => 1);
	$c->redirect_to('/');
};

get '/account' => sub {
	my $c = shift;
	if($c->session('access_token')) {
		$nt->access_token($c->session('access_token'));
		$nt->access_token_secret($c->session('access_token_secret'));
		$c->stash->{screen_name} = $c->session('screen_name');
		$c->render(template => 'account');
	}
	else {
		$c->redirect_to('/');
	}
};

get '/account/new' => sub {
	my $c = shift;
	if ($c->session('access_token')) {
		my $event = $c->req->param('event');
		my $deadline = $c->req->param('deadline');
		my $t = localtime;
		my $reg_date_str = $t->year . '-' . $t->mon . '-' . $t->mday;	
		$db->insert('Deadline', {
			name => $c->session('screen_name'),
			event => $event,
			deadline => $deadline,
			reg_date => $reg_date_str,
		});
		$c->stash->{name} = '@' . $c->session('screen_name');
		$c->stash->{event} = $event;
		$c->stash->{deadline} = $deadline;
		$c->render(template => 'new');
	}
	else {
		$c->redirect_to('/');
	}
};

helper mydecode_utf8 => sub {
	my ($self, $str) = @_;
	return decode_utf8($str);
};

app->sessions->default_expiration(300);
app->secrets([$config->{secret_password}]);
app->start;
