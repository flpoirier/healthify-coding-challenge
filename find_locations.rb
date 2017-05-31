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

def add_columns
  conn = PG.connect(dbname: 'mynewdb')
  conn.exec("ALTER TABLE orgs ADD location VARCHAR")
  conn.exec("ALTER TABLE orgs ADD counties VARCHAR")
end

def process_entries
  conn = PG.connect(dbname: 'mynewdb')
  entries = conn.exec("SELECT * FROM orgs")
  current_percent = 0
  entries.each_with_index do |entry,idx|
    if current_percent < (100 * idx / 20000)
      puts "#{current_percent}% checked..."
      current_percent += 1
    end
    find_location(entry["id"], entry["description"])
    find_counties(entry["id"], entry["description"])
  end
end

def find_counties(id,description)
  results = description.scan(/\s((?:[A-Z]\w*\s)*[A-Z]\w*) County/).flatten.uniq.join("; ")
  if results.length > 0
    $conn.exec("UPDATE orgs SET counties = '#{results}' WHERE id = #{id}")
  end
end

def find_location(id,description)
  results = description.scan(/the ((?:(?!the).)+? area)/).flatten.join("; ")#.gsub(/ and /, '; ')
  if results.split(" ").length.between?(3,7)
    $conn.exec("UPDATE orgs SET location = '#{results}' WHERE id = #{id}")
  end
end

drop_db
create_db
add_columns
$conn = PG.connect(dbname: 'mynewdb')
process_entries
