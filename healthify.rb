require 'pg'
require 'set'

$capitalized_words_and_phrases = {} # this will hold all words and phrases that are capitalized even once
$descriptions_to_correct = [] # this will hold objects corresponding to entries that need correction (with id + description)
$all_correct_descriptions = "" # this will hold a string containing all unaffected descriptions
$dictionary = File.open("./words.txt").read.split("\n").to_set # this is a set of 350,000 English words

# ------------------------------------------------------------------

# the following code converts the data in the csv file to a postgresql database

def create_db
  puts "\nCreating database...\n"
  conn = PG.connect(dbname: 'postgres')
  conn.exec("CREATE DATABASE healthifycodingchallenge")
  conn = PG.connect(dbname: 'healthifycodingchallenge')
  conn.exec("CREATE TABLE orgs ( id INT, description VARCHAR, PRIMARY KEY (id) )")
  conn.exec("COPY orgs(id, description) FROM '/Users/appacademy/Desktop/healthify-coding-challenge/jr_data_engineer_assignment.csv' DELIMITER ',' CSV HEADER")
end

# ------------------------------------------------------------------

# this code drops the database (it's easier than doing it manually every time I rerun the code)

def drop_db
  conn = PG.connect(dbname: 'postgres')
  conn.exec("DROP DATABASE IF EXISTS healthifycodingchallenge")
end

# ------------------------------------------------------------------

# if it is affected, it is added to the $descriptions_to_correct array.

def check_rows
  puts "\nProcessing entries...\n\n"

  # queries the database for all rows

  conn = PG.connect(dbname: 'healthify')
  result = conn.exec("SELECT * FROM orgs")

  current_percent = 0
  total_keys = 20000

  # iterates over every row

  result.each_with_index do |row,idx|
    # prints current progress
    if idx > (current_percent * total_keys / 100)
      puts "#{current_percent}% checked..."
      current_percent += 1
    end
    # each row is first sent through the process_description method
    # if it's affected, it is added to the $descriptions_to_correct array
    # if it's unaffected, the capitalized words/phrases in it are added to $capitalized_words_and_phrases
    # and the entire description is added to $all_correct_descriptions
    process_description(row["id"], row["description"])
  end

  puts "\nEntries processed!\n"

  # once all entries have either been set aside for correction or added to the master description string
  # all words / phrases that are capitalized even once get checked against the master description string
  # to see how they are most frequently capitalized (ex: "nyc" => "NYC", "orange county" => "Orange County")
  check_frequencies

  # then, each affected description is corrected
  $descriptions_to_correct.each do |organization|
    fix_description(organization[:id], organization[:description])
  end
end

# ------------------------------------------------------------------

def process_description(id, description)
  # separates description based on punctuation
  sentences = split_into_sentences(description)

  # needs_correcting is initially set to true.
  # it will be switched to false if even one lowercase word is encountered
  needs_correcting = true

  # this will hold all words and subphrases that are capitalized
  cap_words_and_phrases = []

  sentences.each do |sentence|
    sentence = sentence.split(" ")
    phrase = ""
    sentence.each_with_index do |word,idx|
      # we are trying to identify any words or phrases that are capitalized.
      # capitalized words are added to the phrase string until a lowercase word is identified
      # at which point the phrase is added to the cap_words_and_phrases array and reset to an empty string
      if word == word.downcase && word.to_i == 0 && idx == 1
        # it's important to check word.to_i == 0 because, for example, "8" == "8.downcase"
        # so, for a while, affected descriptions (ex: "Food Pantry Available For 75210 Only.") were marked as unaffected
        # also, we are checking for idx == 1 because the first word in a sentence is always capitalized.
        # if the second word (at idx 1) is also capitalized, I assume that it and the first word are part of a phrase
        # otherwise, I reset the phrase string
        needs_correcting = false
        phrase = ""
      elsif word == word.downcase && word.to_i == 0
        needs_correcting = false
        if phrase.length > 0
          # slice is used to trim the final space from the phrase
          cap_words_and_phrases << phrase.slice(0...-1)
          phrase = ""
        end
      else
        phrase += word += " "
      end
    end
    # adds current phrase to the master array if it's not an empty string
    phrase.length > 0 ? cap_words_and_phrases << phrase.slice(0...-1) : nil
  end
  if needs_correcting
    # if no lowercase words were encountered, the id and description are addeded to $descriptions_to_correct
    $descriptions_to_correct << {id: id, description: description}
  else
    # otherwise, the description is added to $all_correct_descriptions
    # it's important to only add UNAFFECTED descriptions to this because it will be used to analyze correct capitalization
    sentences.each do |sentence|
      sentence = sentence.split(" ")
      # for a while, the program was assuming that words like "provides", "offers" and "serves" should be capitalized
      # because they're disproportionately likely to be the first word in the description (and therefore capitalized)
      # I addressed that by making the first letter in a sentence lowercase (unless the second word is also capitalized)
      if sentence[1] && (sentence[1] == sentence[1].downcase)
        sentence[0][0] = sentence[0][0].downcase
      end
      $all_correct_descriptions += sentence.join(" ") + " "
    end
    # and finally, all capitalized words/phrases are added to the masterlist for processing
    cap_words_and_phrases.each { |word| $capitalized_words_and_phrases[word.downcase] = word }
  end
end

# ------------------------------------------------------------------

# description is separated by punctuation ("!"/"."/","/"?")
# separated strings are returned in an array
# the point of this is to identify the limits of capitalized phrases
# because a phrase will not continue past a punctuation mark
# (ex: "University Of California, Orange County" == 2 separate phrases)

def split_into_sentences(description)
  description = description.split(". ")
  description.map! { |sentence| sentence.split("! ") }.flatten!
  description.map! { |sentence| sentence.split("? ") }.flatten!
  description.map! { |sentence| sentence.split(", ") }.flatten!
  # this removes the final punctuation mark (if it exists)
  /\?|\.|\!/.match(description[-1][-1]) ? description[-1] = description[-1].slice(0...-1) : nil
  description
end

# ------------------------------------------------------------------

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

# ------------------------------------------------------------------

def fix_description(id, description)

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
  insert_correct_description(id, new_description.join(" "))
end

# ------------------------------------------------------------------

def trim_punctuation(description)
  description = description.split(" ")
  punctuation = {}
  description.each_with_index do |word,idx|
    /\?|\.|\!|\,/.match(word[-1]) ? letter = word.slice!(-1) : letter = ""
    punctuation[idx] = letter
  end
  { description: description.join(" "), punctuation: punctuation }
end

# ------------------------------------------------------------------

def restore_punctuation(description, punctuation)
  description = description.split(" ")
  description.each_with_index do |word,idx|
    description[idx] = word + punctuation[idx]
  end
  description.join(" ")
end

# ------------------------------------------------------------------

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

# ------------------------------------------------------------------

def insert_correct_description(id, description)
end

# ------------------------------------------------------------------

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
