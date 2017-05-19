<h1>Junior Data Engineer Assignment (Healthify)</h1>

The basic approach to the problem is pretty simple. I use the Ruby 'pg' gem to import the CSV file into a PostgreSQL database. After that, I retrieve the entire contents of the table in a single query, which returns a PG object. This object can be iterated over like an array -- each row is stored as a hash, with column names as keys and data as values.

The data in each row gets sent to another function. The description (a string) is split into separate words. A variable called next_word_caps is initially set to true (because the first word in a sentence will always be capitalized). Each word in the array is checked. If any of them are uncapitalized, the function returns without doing anything (because an uncapitalized word means the row was unaffected). Otherwise, they are initially downcased. If next_word_caps is set to true, they are capitalized, and next_words caps is reset to false. Then, the last character in the word is checked -- if it's "?", ".", or "!", next_word caps is set to true (because it means we've hit the end of a sentence). Then, the revised word replaces the original word in the array. If we iterate over all the words without returning, we join the description back into a string and send it, with the row id, to a third function, where we update the row in the database with the revised description.

(Considering that 920 rows in the database (or about 5%) were affected, this means that means that this program will make 921 queries. However, it still seems smarter to do them individually, so if an error occurs, it'll only affect a single entry.)

<hr>

The above solution is a decent baseline fix. Here are some examples of successfully corrected entries:

"Provides Licensing Of Families Who Are Interested In Becoming Foster Families." =>
"Provides licensing of families who are interested in becoming foster families."

"Food Pantries Store Food For Those In Need And Distribute It At An Accessible Location. Eligible Participants Can Access Food For Free." =>
"Food pantries store food for those in need and distribute it at an accessible location. Eligible participants can access food for free."

However, there are still issues with proper nouns (specifically, acronyms, places, and organization names). Examples include:

"Provides Fire Protection And Prevention Services For The City Of Seven Hills. Offers Cpr Classes." =>
"Provides fire protection and prevention services for the city of seven hills. Offers cpr classes."

"The Moyock Library Has A Popular Reading Collection For Adults, Teens And Children In Addition To Numerous Special Collections." =>
"The moyock library has a popular reading collection for adults, teens and children in addition to numerous special collections."

<hr>

This is a difficult problem because there is no exhaustive dictionary of proper nouns -- and even if there were, it certainly wouldn't include the names of every local organization referred to in the database.

One possible solution might be to check every word in a sentence against a dictionary, and capitalize the ones that aren't present. This would help with the "Moyock" example above, but would not capitalize "Seven Hills".

If there were columns of organization names and locations, another approach might be to check if those words were included in the corresponding descriptions. However, those are not included in this dataset.

Most likely, it's impossible to identify organization names and locations that need capitalization without using the internet. My chosen approach is to search Google for each description.
