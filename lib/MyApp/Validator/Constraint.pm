package MyApp::Validator::Constraint;
use strict;
use warnings;
use FormValidator::Lite::Constraint;
use FindBin;
use MyApp::Validator::Words;
use utf8;
use Encode qw/decode_utf8/;

my $database = "$FindBin::Bin/" . 'words.db';
my $data_source = "dbi:SQLite:dbname=$database";
my $db = MyApp::Validator::Words->new({
	dsn => $data_source,
	username => '',
	password => '',
});

rule 'IS_RIGHT_WORD' => sub {
	my $text = $_;
	my $itr = $db->search('Words', {});
	while (my $column = $itr->next) {
		my $word = decode_utf8($column->word);
		if ($text =~ /$word/) {
			return 0
		}
	}
	return 1;
};

1;
