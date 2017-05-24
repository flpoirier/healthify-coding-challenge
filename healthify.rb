require 'pg'
require 'set'

$capitalized_words_and_phrases = {}
$descriptions_to_correct = []
$all_correct_descriptions = ""
$dictionary = File.open("./words.txt").read.split("\n").to_set

# the following code converts the data in the csv file to a postgresql database

def create_db
  puts "\nCreating database...\n"
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
  puts "\nProcessing entries...\n\n"

  conn = PG.connect(dbname: 'healthify')
  result = conn.exec("SELECT * FROM orgs")

  current_percent = 0
  total_keys = 20000

  result.each_with_index do |row,idx|
    if idx > (current_percent * total_keys / 100)
      puts "#{current_percent}% checked..."
      current_percent += 1
    end
    process_description(row["id"], row["description"])
  end

  puts "\nEntries processed!\n"

  check_frequencies

  $descriptions_to_correct.each do |organization|
    needs_fixing(organization[:id], organization[:description])
  end
end

def check_frequencies
  puts "\nChecking for capitalization frequencies...\n\n"
  current_percent = 0
  total_keys = $capitalized_words_and_phrases.keys.length
  # I create a new, empty hash so as to not edit the original hash while iterating over it
  new_cap_words_and_phrases = {}
  $capitalized_words_and_phrases.keys.each_with_index do |phrase,idx|
    # This method is the performance bottleneck. It takes about eight minutes.
    # Printing progress updates shows that the program hasn't just frozen.
    if idx > (current_percent * total_keys / 100)
      puts "#{current_percent}% checked..."
      current_percent += 1
    end
    phrase = phrase.split(" ")
    if phrase.length == 1
      # if a phrase is only one word long, I search the correct descriptions for the phrase with a space on either side
      # because words like "NY" or "GED" will return a lot of false positives otherwise (ex: company, many, challenged, managed)
      phrase = phrase[0]
      downcase = $all_correct_descriptions.scan(/(?=#{" " + phrase.downcase + " "})/).count
      capitalized = $all_correct_descriptions.scan(/(?=#{" " + phrase.capitalize + " "})/).count
      uppercase = $all_correct_descriptions.scan(/(?=#{" " + phrase.upcase + " "})/).count
      phrase = phrase.split(" ")
    else
      # the point of this is essentially to search all the unaffected descriptions (~19,000) for the number of
      # lowercase, uppercase, and titlecase instances of each phrase. (ex: "nyc", "NYC", and "Nyc")
      downcase = $all_correct_descriptions.scan(/(?=#{phrase.map(&:downcase).join(" ")})/).count
      capitalized = $all_correct_descriptions.scan(/(?=#{phrase.map(&:capitalize).join(" ")})/).count
      uppercase = $all_correct_descriptions.scan(/(?=#{phrase.map(&:upcase).join(" ")})/).count
    end
    # then, each word or phrase is added to the hash. the key is the lowercase word/phrase
    # and the value is its most common form (either lower, upper or titlecase)
    if (capitalized >= downcase) && (capitalized >= uppercase)
      new_cap_words_and_phrases[phrase.join(" ")] = phrase.map(&:capitalize).join(" ")
    elsif (uppercase >= downcase) && (uppercase >= capitalized)
      new_cap_words_and_phrases[phrase.join(" ")] = phrase.map(&:upcase).join(" ")
    else
      new_cap_words_and_phrases[phrase.join(" ")] = phrase.map(&:downcase).join(" ")
    end
  end
  puts "\nFrequency checking complete!\n"
  # then, the global variable is reset to
  $capitalized_words_and_phrases = new_cap_words_and_phrases
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
    sentences.each do |sentence|
      sentence = sentence.split(" ")
      if sentence[1] && (sentence[1] == sentence[1].downcase)
        sentence[0][0] = sentence[0][0].downcase
      end
      $all_correct_descriptions += sentence.join(" ") + " "
    end
    cap_words_and_phrases.each { |word| $capitalized_words_and_phrases[word.downcase] = word }
  end
end

def needs_fixing(id, description)

  new_description = description
  desc_and_punc = trim_punctuation(new_description)
  sentences = sentence_subsets(desc_and_punc[:description])
  new_description = restore_punctuation(sentences, desc_and_punc[:punctuation])

  next_word_caps = true # the first word in the description should always be capitalized
  new_description = new_description.split(" ")

  new_description.each_with_index do |word,idx|
    if next_word_caps
      word[0] = word[0].upcase   # word gets capitalized if it's at beginning of a new sentence
      next_word_caps = false # this variable resets
    end
    /\?|\.|\!/.match(word[-1]) ? next_word_caps = true : nil # if a word ends in "?", ".", or "!", we know it's at the end of a sentence, and the next word should be capitalized
    new_description[idx] = word # finally, we replace the word in the description with the corrected word
  end

  puts description
  puts new_description.join(" ")
  puts "\n"
  insert_correct_description(id, new_description.join(" ")) # if we haven't returned by this point, we know the description needs fixing
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
  description = description.split(" ").map(&:downcase)
  idx1 = 0
  while idx1 < description.length
    idx2 = idx1
    while idx2 < description.length
      subset = description[idx1..idx2].join(" ").downcase
      correct_subset = $capitalized_words_and_phrases[subset]
      if correct_subset
        correct_subset.split(" ").each_with_index do |word,idx|
          description[idx1 + idx] = word
        end
      elsif idx1 == idx2
        description[idx1] = subset.capitalize unless $dictionary.include?(subset)
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

p $capitalized_words_and_phrases.sort
# p $capitalized_words_and_phrases.length
# p $descriptions_to_correct.length
#
# string = "This is my sentence. This is another sentence! This is a third sentence."
# p split_into_sentences(string)

# avg word length = 15
# avg google queries = 120 per description
# how to enter a google search -- https://www.google.com/search?q=yourquery
