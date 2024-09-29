#!/bin/bash

# Directory containing the CSV files
CSV_DIR="path/to/your/data"

# MySQL connection details
DB_NAME="name"
HOST="localhost"
LOGIN_PATH="local"  # Assumes you have stored your username and password in mysql_config_editor

# Loop through all CSV files in the directory
for CSV_FILE in "$CSV_DIR"/*.csv; do
    
    # Extract the table name from the file name, replacing hyphens with underscores
    table_name=$(basename "$CSV_FILE" .csv | tr '-' '_')
    
    # Check if the file exists
    if [ ! -f "$CSV_FILE" ]; then
        echo "CSV file $CSV_FILE does not exist. Skipping."
        continue
    fi
    
    echo "Processing file: $CSV_FILE"
    
    # Check the file encoding
    file_encoding=$(file -I "$CSV_FILE" | awk -F'=' '{print $2}')
    echo "Detected file encoding for $CSV_FILE: $file_encoding"
    
    # Create a temporary file for conversion, if needed
    converted_file=$(mktemp)
    
    # Fallback strategy if encoding is not recognized by iconv
    if [[ "$file_encoding" == "unknown-8bit" || "$file_encoding" == "us-ascii" ]]; then
        echo "Unknown or unsupported encoding detected. Assuming ISO-8859-1 (Latin-1)."
        file_encoding="ISO-8859-1"
    fi
    
    # If the file is not in UTF-8, convert it
    if [[ "$file_encoding" != "utf-8" ]]; then
        echo "Converting $CSV_FILE to UTF-8 using encoding: $file_encoding"
        if ! iconv -f "$file_encoding" -t utf-8//IGNORE "$CSV_FILE" > "$converted_file"; then
            echo "Error during conversion of $CSV_FILE. Skipping."
            rm -f "$converted_file"  # Clean up temporary file
            continue
        fi
        CSV_FILE="$converted_file"
        echo "Conversion complete. Using converted file: $CSV_FILE"
    else
        echo "File is already UTF-8 encoded. No conversion needed."
        rm -f "$converted_file"  # Clean up the unused temp file since no conversion happened
    fi
    
    # Read the first line of the CSV to get the column names
    headers=$(head -n 1 "$CSV_FILE" | tr -d '\r')
    
    # Split headers into an array and print each for inspection
    IFS=',' read -ra header_array <<< "$headers"
    echo "Parsed column names: ${header_array[@]}"
    
    # Function to clean and format column names with backticks
    quote_column_name() {
        local column_name="$1"
        # Trim spaces, remove carriage returns, and remove any quotes (single and double)
        column_name=$(echo "$column_name" | sed 's/^ *//;s/ *$//;s/[\"'\'']//g')
        echo "\`$column_name\`"
    }
    
    # Convert all headers into SQL column definitions, setting each column as TEXT
    columns=""
    for header in "${header_array[@]}"; do
        # Properly quote each column name individually
        column=$(quote_column_name "$header")
        echo "Formatted column: $column"
        columns+="$column TEXT, "
    done
    
    # Remove the trailing comma and space
    columns=$(echo "$columns" | sed 's/, $//')
    
    # Check if columns are valid (not empty)
    if [ -z "$columns" ]; then
        echo "No valid columns found for $CSV_FILE. Skipping."
        continue
    fi
    
    # Create the SQL command for creating the table
    create_table_command="CREATE TABLE IF NOT EXISTS \`$table_name\` ($columns);"
    
    # Output the SQL command for verification
    echo "Generated SQL command for table creation (all columns):"
    echo "$create_table_command"
    
    # Execute the table creation command
    if ! /usr/local/bin/mysql --login-path=$LOGIN_PATH -h $HOST -D $DB_NAME -e "$create_table_command"; then
        echo "Error creating table $table_name. Skipping this file."
        continue
    else
        echo "Created table: $table_name"
    fi
    
    # Import the CSV data into the created table
    load_data_command="LOAD DATA LOCAL INFILE '$CSV_FILE' INTO TABLE \`$table_name\` FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;"
    if ! /usr/local/bin/mysql --login-path=$LOGIN_PATH --local-infile=1 -h $HOST -D $DB_NAME -e "$load_data_command"; then
        echo "Error importing data into table $table_name. Skipping this file."
        continue
    else
        echo "Imported data from $CSV_FILE into table $table_name"
    fi
    
    # Clean up temporary file if it was used
    if [[ "$CSV_FILE" == "$converted_file" ]]; then
        rm -f "$converted_file"
        echo "Temporary file $converted_file removed."
    fi
    
done

echo "All CSV files have been processed."
