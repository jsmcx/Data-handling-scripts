# Data handling scripts
Only one script here at present, chosen because it's generic enough to be helpful to many situations, and doesn't contain any private information. I might add more as time goes on.

## Import csv to sql

Shell script that parses a folder of CSV files and imports to MySQL. 
The CSV filenames will be used the table names.

Assumes that you have your MySQL username and password stored in mysql_config_editor, which is pretty standard these days, and is now enforced as of version 9

Full breakdown of the script can be found at (this Medium post)[https://medium.com/@jsmx/we-choose-to-import-hundreds-of-csv-files-not-because-it-was-easy-but-because-we-thought-it-would-dfb1e02a2467].