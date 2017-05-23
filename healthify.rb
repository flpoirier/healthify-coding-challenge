require 'pg'

$capitalized_words_and_phrases = []
$descriptions_to_correct = []

# the following code converts the data in the csv file to a postgresql database

def create_db
  conn = PG.connect(dbname: 'postgres')
  conn.exec("CREATE DATABASE healthify")
  conn = PG.connect(dbname: 'healthify')
  conn.exec("CREATE TABLE orgs ( id INT, description VARCHAR, PRIMARY KEY (id) )")
  conn.exec("COPY orgs(id, description) FROM '/Users/appacademy/Desktop/healthify-coding-challenge/jr_data_engineer_assignment.csv' DELIMITER ',' CSV HEADER")
end

def drop_db
  conn = PG.connect(dbname: 'postgres')
  conn.exec("DROP DATABASE healthify")
end

def check_rows
  conn = PG.connect(dbname: 'healthify')
  result = conn.exec("SELECT * FROM orgs")
  result.each do |row|
    process_description(row["id"], row["description"])
  end
end

def split_into_sentences(description)
  description = description.split(". ")
  description.map! { |sentence| sentence.split("! ") }.flatten!
  description.map! { |sentence| sentence.split("? ") }.flatten!
  description.map! { |sentence| sentence.split(", ") }.flatten!
  /\?|\.|\!/.match(description[-1][-1]) ? description[-1] = description[-1].slice(0...-1) : nil
  description
end

def process_description(id, description)
  p description
  sentences = split_into_sentences(description)
  needs_correcting = true
  cap_words_and_phrases = []
  sentences.each do |sentence|
    sentence = sentence.split(" ")
    phrase = ""
    sentence.each_with_index do |word,idx|
      if word == word.downcase && idx == 1
        needs_correcting = false
        phrase = ""
      elsif word == word.downcase
        needs_correcting = false
        if phrase.length > 0 #&& (word == "and" || word == "the" || word == "of")
        #   phrase += word += " "
        # elsif phrase.length > 0
          cap_words_and_phrases << phrase.slice(0...-1)
          phrase = ""
        end
      else
        phrase += word += " "
      end
    end
    phrase.length > 0 ? cap_words_and_phrases << phrase.slice(0...-1) : nil
  end
  if needs_correcting
    p description
    $descriptions_to_correct << {id: id, description: description}
  else
    p cap_words_and_phrases
    $capitalized_words_and_phrases << cap_words_and_phrases
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
  p description.join(" ")
  p new_description.join(" ")
  insert_correct_description(id, description.join(" ")) # if we haven't returned by this point, we know the description needs fixing
end

def insert_correct_description(id, description)
end

drop_db
create_db
check_rows

p $capitalized_words_and_phrases.flatten.uniq.sort
p $capitalized_words_and_phrases.flatten.uniq.length
p $descriptions_to_correct.length

# avg word length = 15
# avg google queries = 120 per description
# how to enter a google search -- https://www.google.com/search?q=yourquery
