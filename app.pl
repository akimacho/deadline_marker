#!/usr/bin/env perl
use Mojolicious::Lite;
use Encode qw/encode_utf8 decode_utf8/;
use FindBin;
use lib "$FindBin::Bin/lib/";
use Net::Twitter::Lite;
use Time::Piece;
use MyApp::DB;
use FormValidator::Lite;

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
	$c->stash->{Deadline} = $db->search('Deadline', {});
	# すでにログインされているかどうか
	$c->stash->{is_login} = $c->session('access_token') ? 1 : 0;
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
		$c->stash->{Deadline} = $db->search('Deadline', {});
		$c->stash->{login_failed} = "ログインできませんでした";
		$c->stash->{is_login} = $c->session('access_token') ? 1 : 0;
		$c->render(template => 'index');
	}
};

get '/logout' => sub {
	my $c = shift;
	if($c->session('access_token')) {# ログイン済みである場合
		$c->session(expires => 1);
		$c->stash->{Deadline} = $db->search('Deadline', {});
		$c->stash->{logout_ok} = "ログアウトしました";
		$c->stash->{is_login} = 0;
		$c->render(template => 'index');
	}
	else {# ログインされていない場合
		$c->redirect_to('/');
	}
};

get '/account' => sub {
	my $c = shift;
	if($c->session('access_token')) {# ログイン済みである場合
		$c->stash->{screen_name} = $c->session('screen_name');
		$c->render(template => 'account');
	}
	else {# ログインされていない場合
		$c->redirect_to('/');
	}
};

post '/account' => sub {
	my $c = shift;
	if ($c->session('access_token')) {# ログイン済みである場合
		$c->stash->{screen_name} = $c->session('screen_name');
		my $validator = FormValidator::Lite->new($c->req);
		$validator->load_function_message('ja');
		$validator->set_param_message(
			event		 => 'イベント',
			deadline => '日付',
		);
		my $res = $validator->check(
			event => [qw/NOT_NULL/],
			deadline => [qw/NOT_NULL/],
		);
		if ($validator->has_error) {# バリデーションに失敗した場合
			my $messages = $validator->get_error_messages();
			$c->stash->{messages} = $messages;
			return $c->render(template => 'account');
		}
		else {# バリデーションに成功した場合
			my $event = $c->req->param('event');
			my $deadline = $c->req->param('deadline');
			my $t = localtime;
			# 日時の形式 : 年-月-日-時-分-秒
			my $reg_date =
				join('-', ($t->year, $t->mon, $t->mday, $t->hour, $t->min, $t->sec));
			# 登録者名,イベント名,締切日,登録日を登録する
			$db->insert('Deadline', {
				name		 => $c->session('screen_name'),
				event		 => $event,
				deadline => $deadline,
				reg_date => $reg_date,
			});
			$c->stash->{messages} = [qw/締切日の入力を受け取りました/];
			return $c->render(template => 'account');
		}
	}
	else {# ログインされていない場合
		$c->redirect_to('/');
	}
};

helper mydecode_utf8 => sub {
	my ($self, $str) = @_;
	return decode_utf8($str);
};

app->sessions->default_expiration(240);
app->secrets([$config->{secret_password}]);
app->start;
