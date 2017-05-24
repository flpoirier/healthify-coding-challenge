<h1>Junior Data Engineer Assignment (Healthify)</h1>

This was a very interesting problem!

The naive approach to the problem is pretty simple. After using the Ruby 'pg' gem to import the CSV file into a PostgreSQL database, we then retrieve the entire contents of the table in a single query. The data in each row gets sent to another function, where we split the description into words. If any of the words are not capitalized, we know the description was unaffected and return early from the function. Otherwise, we use regular expressions to identify sentences within the description. We then capitalize the first word of every sentence and downcase every other word, and update the database with the corrected description.

(Considering that more than 1,000 rows in the database (or about 5%) were affected, this means that this program will make 1,000+ queries to the database. However, it still seems smarter to do them individually, so if an error occurs, it'll only affect a single entry.)

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

This is a difficult problem because there is no exhaustive dictionary of proper nouns -- and even if there were, it certainly wouldn't include the names of every local organization referred to in the database. However, we have one advantage: 19,000 unaffected descriptions. Many organizations, acronyms, and places are referred to more than once in the database. Therefore, analysis of the unaffected descriptions can help guide correction of the affected descriptions.

I chose a three-step approach to this problem:

1. Examine the 19,000 unaffected descriptions for any words (ex: "NYC") or phrases (ex: "Orange County") that are capitalized even once. Then, analyze the 19,000 unaffected descriptions for the most common capitalization of each, and store the results in a hash. Iterate over each affected description for instances of commonly capitalized words and phrases.

2. Check individual words in affected descriptions against a dictionary of common English words. Capitalize any words that are not present in the dictionary (ex: "Lemoore", "Sendero").

3. Finally, implement the naive approach above to ensure that the first word of every sentence is capitalized.

<hr>

This multipronged approach is much more successful than the naive approach alone. Here are some examples of successfully corrected entries:

"Provides Food Boxes On A Monthly Basis To Needy Families In Lemoore." =>
"Provides food boxes on a monthly basis to needy families in Lemoore."

"Provides Testing For Sexually Transmitted Diseases And Hiv. Referred Out For Hepatitis C Testing." =>
"Provides testing for sexually transmitted diseases and HIV. Referred out for Hepatitis C testing."

"Provides Home Health And Hospice Services To Residents Of Alleghany, Ashe And Watauga Counties." =>
"Provides home health and hospice services to residents of Alleghany, Ashe and Watauga counties."

"The Sendero Program Is Specifically For Latino Consumers Whose Primary Language Is Spanish." =>
"The Sendero program is specifically for Latino consumers whose primary language is Spanish."

"Food Pantry By Appointment On Tuesdays And Thursdays." =>
"Food pantry by appointment on Tuesdays and Thursdays."

"Reach Provides Aoda Services Including Assessment And Diagnostic Evaluations Alcohol And Drug Treatment Groups And Owi Education Groups." =>
"Reach provides AODA services including assessment and diagnostic evaluations alcohol and drug treatment groups and OWI education groups."

<hr>

However, it does have limitations:

1. The code takes more than 10 minutes to run. There are about 7,000 capitalized words and phrases, and I search the 19,000 entries for each of them three times (for capitalized, lowercase, and uppercase instances) -- more than 20,000 searches. This takes more than 8 minutes and is the major performance bottleneck.

2. The unaffected entries are often poorly or inconsistently capitalized. Any common errors in the unaffected code will carry over into the capitalization analysis.

3. Some words are both acronyms and normal words (ex: 'aids' / 'AIDS'; 'add' / 'ADD'). The code can't distinguish between them.

4. Some phrases don't appear in the database enough to be analyzed. (Ex: "Seven Hills" only occurs once, and since it's a phrase composed of regular words, it doesn't get corrected.)

5. It doesn't deal properly with phrases with hybrid capitalization (ex: the program analyzes "GED preparation" as "ged preparation").

It might be possible to address some of these concerns by analyzing even larger text samples (perhaps scraped from books and news sites). However, that would make the code run even more slowly. This solution is imperfect but (I think) sufficient.

<hr>

Another approach I seriously considered was searching the internet for each affected description. A random sample suggests that at least half of them are accessible via Google Search -- this would be a good way of retrieving the original capitalization. The problem with this is that Google limits searches to 100 / day, and charges for any additional searches. (It's probably possible to get around this limit by using proxies, but I considered that beyond the scope of this coding challenge.)

<hr>

Thanks for the challenge! I genuinely enjoyed it. Please let me know if there's anything I can correct or clarify.
