require 'pg'

$capitalized_words_and_phrases = {}
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
  $descriptions_to_correct.each do |organization|
    needs_fixing(organization[:id], organization[:description])
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
  sentences = split_into_sentences(description)
  needs_correcting = true
  cap_words_and_phrases = []
  sentences.each do |sentence|
    sentence = sentence.split(" ")
    phrase = ""
    sentence.each_with_index do |word,idx|
      if word == word.downcase && word.to_i == 0 && idx == 1
        needs_correcting = false
        phrase = ""
      elsif word == word.downcase && word.to_i == 0
        needs_correcting = false
        if phrase.length > 0
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
    $descriptions_to_correct << {id: id, description: description}
  else
    cap_words_and_phrases.each { |word| $capitalized_words_and_phrases[word.downcase] = word }
  end
end

def needs_fixing(id, description)
  description = description.split(" ") # description is split into an array of individual words
  new_description = []
  next_word_caps = true # the first word in the description should always be capitalized

  description.each_with_index do |word,idx|
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

def trim_punctuation(description)
  description = description.split(" ")
  punctuation = {}
  description.each_with_index do |word,idx|
    /\?|\.|\!|\,/.match(word[-1]) ? letter = word.slice!(-1) : letter = ""
    punctuation[idx] = letter
  end
  { description: description.join(" "), punctuation: punctuation }
end

def restore_punctuation(description, punctuation)
  description = description.split(" ")
  description.each_with_index do |word,idx|
    description[idx] = word + punctuation[idx]
  end
  description.join(" ")
end

def sentence_subsets(description)
  description = description.split(" ")
  idx1 = 0
  while idx1 < description.length
    idx2 = idx1
    while idx2 < description.length
      subset = description[idx1..idx2].join(" ")
      correct_subset = $capitalized_words_and_phrases[subset]
      if correct_subset
        correct_subset.split(" ").each_with_index do |word,idx|
          description[idx1 + idx] = word
        end
      end
      idx2 += 1
    end
    idx1 += 1
  end
  description.join(" ")
end

def insert_correct_description(id, description)
end

drop_db
create_db
check_rows

# p $capitalized_words_and_phrases.sort
# p $capitalized_words_and_phrases.length
# p $descriptions_to_correct.length

p $capitalized_words_and_phrases["moyock"]
string = "I love clark county very, very much. i love nyc."
obj = trim_punctuation(string)
p obj
desc = sentence_subsets(obj[:description])
p desc
p restore_punctuation(desc, obj[:punctuation])

# avg word length = 15
# avg google queries = 120 per description
# how to enter a google search -- https://www.google.com/search?q=yourquery
