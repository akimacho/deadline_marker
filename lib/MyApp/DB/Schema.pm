package MyApp::DB::Schema;
use DBIx::Skinny::Schema;

install_table Deadline => schema {
	pk 'id';
	#columns qw/id name event deadline reg_date/;
	columns qw/id
						 screen_name user_id
						 event_title event_date event_sense event_description
						 good bad
						 registration_date/;
};

1;
