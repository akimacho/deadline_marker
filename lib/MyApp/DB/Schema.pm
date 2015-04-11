package MyApp::DB::Schema;
use DBIx::Skinny::Schema;

install_table Deadline => schema {
	pk 'id';
	columns qw/id name event deadline reg_date/;
};

1;
