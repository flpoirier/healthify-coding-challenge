require 'pg'

def create_db
  conn = PG.connect(dbname: 'postgres')
  conn.exec("CREATE DATABASE mynewdb")
  conn = PG.connect(dbname: 'mynewdb')
  conn.exec("CREATE TABLE orgs(id INT, description VARCHAR, PRIMARY KEY (id) )")
  conn.exec("COPY orgs (id, description) FROM '/Users/appacademy/Desktop/healthify-coding-challenge/updated_csv_file.csv' DELIMITER ',' CSV HEADER")
end

def drop_db
  conn = PG.connect(dbname: 'postgres')
  conn.exec("DROP DATABASE IF EXISTS mynewdb")
end

def add_location_column
  conn = PG.connect(dbname: 'mynewdb')
  conn.exec("ALTER TABLE orgs ADD location VARCHAR")
end

def process_entries
  conn = PG.connect(dbname: 'mynewdb')
  entries = conn.exec("SELECT * FROM orgs")
  entries.each { |entry| print_location(entry["id"], entry["description"]) }
end

def print_location(id,description)
  results = description.scan(/the ((?:(?!the).)+? area)/).flatten.join("; ")#.gsub(/ and /, '; ')
  if results.split(" ").length.between?(3,7)
    $conn.exec("UPDATE orgs SET location = '#{results}' WHERE id = #{id}")
  end
end

drop_db
create_db
add_location_column
$conn = PG.connect(dbname: 'mynewdb')
process_entries
