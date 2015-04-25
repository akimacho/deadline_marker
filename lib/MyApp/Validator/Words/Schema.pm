package MyApp::Validator::Words::Schema;
use DBIx::Skinny::Schema;

install_table Words => schema {
	pk 'id';
	columns qw/id word/;
};

1;
