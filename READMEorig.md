<h1>Junior Data Engineer Assignment (Healthify)</h1>

The basic approach to the problem is pretty simple. I use the Ruby 'pg' gem to import the CSV file into a PostgreSQL database. After that, I retrieve the entire contents of the table in a single query, which returns a PG object. This object can be iterated over like an array -- each row is stored as a hash, with column names as keys and data as values.

The data in each row gets sent to another function. The description (a string) is split into separate words. A variable called next_word_caps is initially set to true (because the first word in a sentence will always be capitalized). Each word in the array is checked. If any of them are uncapitalized, the function returns without doing anything (because an uncapitalized word means the row was unaffected). Otherwise, they are initially downcased. If next_word_caps is set to true, they are capitalized, and next_words caps is reset to false. Then, the last character in the word is checked using regular expressions -- if it's "?", ".", or "!", next_word caps is set to true (because it means we've hit the end of a sentence). Then, the revised word replaces the original word in the array. If we iterate over all the words without returning, we join the description back into a string and send it, with the row id, to a third function, where we update the row in the database with the revised description.

(Considering that 920 rows in the database (or about 5%) were affected, this means that means that this program will make 921 queries to the database. However, it still seems smarter to do them individually, so if an error occurs, it'll only affect a single entry.)

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

Most likely, it's impossible to identify organization names and locations that need capitalization without using the internet. My chosen approach is to search Google for each description and scrape the results.

Now, the question becomes, what exactly should we search Google for? Since many of these descriptions were taken from the internet, a search for the entire string, in quotes, would often be successful. However, not all descriptions can be found online.

Another approach might be to search Google for each individual word in the description. This would identify the proper capitalization for words like "GreenPath" or "Abilene". However, it wouldn't help with phrases like "Rose Hill Community Center".

So, another possibility would be to search Google for each subset of words within a given description. However, this is subject to severe performance issues. Given a set of length n, there are (n+1)*(n/2) possible ordered subsets. (Example: Set 'ABC' contains six subsets: 'A', 'AB', 'ABC', 'B', 'BC', and 'C'.) The average affected description in the dataset is 15 words long, which means that it contains 120 possible subphrases. 120 subphrases times 920 affected descriptions comes out to 110,400 separate Google searches -- not very efficient!

<hr>

I have chosen to combine these approaches. For each affected description, the first step is to Google the entire phrase. If it occurs on the internet, I will adopt the given capitalization. If it doesn't, I will search every subphrase as outlined above. Finally, I will run it through the baseline algorithm to ensure that every word at the beginning of a sentence is capitalized.

<hr>

More examples:

The Sendero Program Is Specifically For Latino Consumers Whose Primary Language Is Spanish. =>
The Sendero program is specifically for Latino consumers whose primary language is Spanish.

Currently Screening For Waiting List. Single Women With Children Only. =>
Currently screening for waiting list. Single women with children only.

Food Pantry By Appointment On Tuesdays And Thursdays. =>
Food pantry by appointment on Tuesdays and Thursdays.

Aarp Tax Preparation Assistance For Low Income Individuals And Families With Simple Tax Forms. =>
AARP tax preparation assistance for low income individuals and families with simple tax forms.

This Library Provides Book Loans And Story Hour. =>
This library Provides book loans and story hour.

Provides Liheap And Emergency Utility Assistance, Distributes Usda Commodities And Senior Aid Program That Offers Job Training For Persons 55 And Older Seeking New Employment. =>
Provides LIHEAP and emergency utility assistance, distributes USDA commodities and senior aid program that Offers job training for persons 55 and older seeking new employment.

The Eureka Senior Center Serves Congregate Meals Daily. =>
The Eureka Senior Center Serves congregate meals daily.

Information On Alcoholics Anonymous Meetings In Nebraska, Available By Telephone Or Online =>
Information on Alcoholics Anonymous meetings in Nebraska, available by telephone or online

Free Pregnancy Testingfree Pregnancy Counselingpost Abortion Counselingabstinence Educationspecialized Information And Referralvolunteer Based Center =>
Free pregnancy Testingfree pregnancy Counselingpost abortion Counselingabstinence Educationspecialized information and Referralvolunteer based Center
