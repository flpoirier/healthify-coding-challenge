require 'pg'

# the following code converts the data in the csv file to a postgresql database

$total = 0
$total_description_length = 0

def create_db
  # conn = PG.connect(dbname: 'postgres')
  # conn.exec("CREATE DATABASE healthify")
  conn = PG.connect(dbname: 'healthify')
  # conn.exec("CREATE TABLE orgs ( id INT, description VARCHAR, PRIMARY KEY (id) )")
  conn.exec("COPY orgs(id, description) FROM '/Users/appacademy/Desktop/healthify-coding-challenge/jr_data_engineer_assignment.csv' DELIMITER ',' CSV HEADER")
end

def check_rows
  conn = PG.connect(dbname: 'healthify')
  result = conn.exec("SELECT * FROM orgs")
  result.each do |row|
    needs_fixing?(row["id"], row["description"])
  end
end

def needs_fixing?(id, description)
  description = description.split(" ") # description is split into an array of individual words
  new_description = []
  next_word_caps = true # the first word in the description should always be capitalized
  description.each_with_index do |word,idx|
    return if word == word.downcase # if any word in the description is lowercase, we know the description wasn't affected, and we can exit the function
    word = word.downcase # default action is to downcase the word.
    if next_word_caps
      word = word.capitalize # word gets capitalized if it's at beginning of a new sentence
      next_word_caps = false # this variable resets
    end
    /\?|\.|\!/.match(word[-1]) ? next_word_caps = true : nil # if a word ends in "?", ".", or "!", we know it's at the end of a sentence, and the next word should be capitalized
    new_description[idx] = word # finally, we replace the word in the description with the corrected word
  end
  # p id + " " + description.join(" ")
  p description.join(" ")
  p new_description.join(" ")
  $total += 1
  $total_description_length += description.length
  insert_correct_description(id, description.join(" ")) # if we haven't returned by this point, we know the description needs fixing
end

def insert_correct_description(id, description)
end

# create_db
check_rows
p $total
p $total_description_length / $total # avg length = 15
# avg google queries = 120 per description

# needs_fixing?(1,"Hey. I'm A Sentence! Hear Me Roar? Heck Yeah.")
