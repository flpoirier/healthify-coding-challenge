<h1>Junior Data Engineer Assignment (Healthify)</h1>

The basic approach to the problem is pretty simple. I use the Ruby 'pg' gem to import the CSV file into a PostgreSQL database. After that, I retrieve the entire contents of the table in a single query, which returns a PG object. This object can be iterated over like an array -- each row is stored as a hash, with column names as keys and data as values.

The data in each row gets sent to another function. The description (a string) is split into separate words. A variable called next_word_caps is initially set to true (because the first word in a sentence will always be capitalized). Each word in the array is checked. If any of them are uncapitalized, the function returns without doing anything (because an uncapitalized word means the row was unaffected). Otherwise, they are initially downcased. If next_word_caps is set to true, they are capitalized, and next_words caps is reset to false. Then, the last character in the word is checked -- if it's "?", ".", or "!", next_word caps is set to true (because it means we've hit the end of a sentence). Then, the revised word replaces the original word in the array. If we iterate over all the words without returning, we join the description back into a string and send it, with the row id, to a third function, where we update the row in the database with the revised description.

(Considering that 920 rows in the database (or about 5%) were affected, this means that means that this program will make 921 queries. However, it still seems smarter to do them individually, so if an error occurs, it'll only affect a single entry.)

The above solution is a decent baseline fix. Here are some examples of successfully corrected entries:

"Provides Licensing Of Families Who Are Interested In Becoming Foster Families." =>
"Provides licensing of families who are interested in becoming foster families."

"Patrol In A Public Area Concerning The Care And Treatment Of Animals." =>
"Patrol in a public area concerning the care and treatment of animals."

However, there are still issues with proper nouns (specifically, acronyms, places, and organization names). Examples include:

"Provides Fire Protection And Prevention Services For The City Of Seven Hills. Offers Cpr Classes." =>
"Provides fire protection and prevention services for the city of seven hills. Offers cpr classes."

"The Moyock Library Has A Popular Reading Collection For Adults, Teens And Children In Addition To Numerous Special Collections." =>
"The moyock library has a popular reading collection for adults, teens and children in addition to numerous special collections."
