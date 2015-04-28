CREATE TABLE Deadline (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  screen_name TEXT NOT NULL,
  user_id TEXT NOT NULL,
  event_title TEXT NOT NULL,
  event_sense TEXT NOT NULL,
  event_date TEXT NOT NULL,
  event_description TEXT,
  good INTEGER NOT NULL,
  bad INTEGER NOT NULL,
  registration_date NUMERIC NOT NULL
);
