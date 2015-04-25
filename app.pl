#!/usr/bin/env perl
use Mojolicious::Lite;
use Encode qw/encode_utf8 decode_utf8/;
use FindBin;
use lib "$FindBin::Bin/lib/";
use Net::Twitter::Lite;
use Time::Piece;
use MyApp::DB;
use FormValidator::Lite;
FormValidator::Lite->load_constraints(qw/DATE +MyApp::Validator::Constraint/);

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

my $db = MyApp::DB->new({dsn => 'dbi:SQLite:dbname=events.db'});

get '/' => sub {
  my $c = shift;
	$c->stash->{deadlines} = $db->search('Deadline', {});
  $c->render(template => 'index');
};

get '/login' => sub {
	my $c = shift;
	my $url = $nt->get_authorization_url(callback => $c->req->url->base() . '/callback');
	$c->session(
		token				 => $nt->request_token(),
		token_secret => $nt->request_token_secret(),
	);
	$c->redirect_to($url);
};

get '/callback' => sub {
	my $c = shift;
	unless ($c->req->param('denied')) {# Twitter認証に成功した場合
		$nt->request_token($c->session('token'));
		$nt->request_token_secret($c->session('token_secret'));
		my ($access_token, $access_token_secret, $user_id, $screen_name)
			= $nt->request_access_token(verifier => $c->req->param('oauth_verifier'));
		$c->session(
			access_token				=> $access_token,
			access_token_secret => $access_token_secret,
			user_id							=> $user_id,
			screen_name					=> $screen_name,
		);
		$c->redirect_to('/account');
	}
	else {# Twitter認証に失敗した場合
		$c->redirect_to('/');
	}
};

get '/logout' => sub {
	my $c = shift;
	$c->session(expires => 1) if($c->session('access_token'));# ログイン済みである場合
	$c->redirect_to('/');
};

get '/account' => sub {
	my $c = shift;
	if($c->session('access_token')) {# ログイン済みである場合
		$c->render(template => 'account');
	}
	else {# ログインされていない場合
		$c->redirect_to('/');
	}
};

post '/account' => sub {
	my $c = shift;
	if ($c->session('access_token')) {# ログイン済みである場合
		my $validator = FormValidator::Lite->new($c->req);
		$validator->load_function_message('ja');
		$validator->set_param_message(
			title				=> 'イベント',
			date				=> '日付',
			description => '詳細',
		);
		$validator->set_message(
			'title.is_right_word' => '不正ワードが検出されました',
			'description.is_right_word' => '不正ワードが検出されました',
		);
		my $res = $validator->check(
			title	=> [qw/NOT_NULL/],
			date	=> [qw/DATE NOT_NULL/],
			description => [qw/IS_RIGHT_WORD/],
		);

		if ($validator->has_error) {# バリデーションに失敗した場合
			$c->stash->{messages} = $validator->get_error_messages();;
			return $c->render(template => 'account');
		}
		else {# バリデーションに成功した場合
			my $event_title = $c->req->param('title');
			my $event_date	= $c->req->param('date');
			my $event_sense = $c->req->param('event_sense');
			my $description = $c->req->param('description');
			my $t = localtime;
			my $reg_date =
				join('-', ($t->year, $t->mon, $t->mday, $t->hour, $t->min, $t->sec));
			$db->insert('Deadline', {
				screen_name				=> $c->session('screen_name'),
				event_title				=> $event_title,
				user_id						=> $c->session('user_id'),
				event_date				=> $event_date,
				event_sense				=> $event_sense,
				event_description => $description,
				good							=> 0,
				bad								=> 0,
				registration_date => $reg_date,
			});
			$c->stash->{messages} = [qw/入力を受付けました/];
			return $c->render(template => 'account');
		}
	}
	else {# ログインされていない場合
		$c->redirect_to('/');
	}
};

get '/entry/:id' => sub {
	my $c = shift;
	my $id = $c->stash->{id};
	my $itr = $db->search('Deadline', {id => $id},);
	$c->stash->{deadline} = $itr->first->{row_data};
	$c->render(template => 'entry');
};

helper mydecode_utf8 => sub {
	my ($self, $str) = @_;
	return decode_utf8($str);
};

helper getJPNDate => sub {
	my ($self, $event_date) = @_;
	my ($year, $month, $day) = split(/-/, $event_date);
	my $date = localtime->strptime($year . '-' . $month . '-' . $day, '%Y-%m-%d');
	my $wday = $date->wdayname(qw/日 月 火 水 木 金 土/);
	return $year . "年" . $month . "月" . $day . "日" . "(" . $wday . ")";
};

app->sessions->default_expiration(300);
app->secrets([$config->{secret_password}]);
app->start;
