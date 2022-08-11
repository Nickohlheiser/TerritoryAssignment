# INTRO
This was a sample project I found online with the goal of creating automation to assign the Account, Contact, and Opportunity (open) Owner based on the Postal Code of the Account (on insert & update)


## Territory & Postal Code Matching
The code will lookup a Territory__c record (Name) which best matches the Postal Code on the account; wildcards in the Territory are supported.
eg: An account with Postal Code '12345' will match Territory '12345'

Wildcards on the Territory object are supported
eg: An account with Postal Code '12345' will match Territory '123%'

If an account matches multilpe Territory records the Territory with the most granularity will be used for assignment.
eg: Account with Postal Code '12345' will match Territory '1234%' even if '123%' exists.  Account with '12399' would match '123%'

A duplicate rule prevents multiple Territories with the same name
A validation rule forces the Name to be up to 5 characters.  Also only allows numbers and '%' (wildcard)


## Territory Assignment (TA)
The Territory Assignment is what defines the users who should own accounts in this Territory

Each Terrory can have a maximum of 3 Territory Assignments

Duplicate Assignee__c values aren't allowed for the same Territory.  This is accomplished by the Territory Assignment trigger populating the Duplicate_Key__c which is a composite key concatenating the Territory__c & Assignee__c values & the field being marked as an External Key & set as unique


# Assigning new owners
One of the bonus challenges was to evenly distribute the accounts across the TA's.  I added my own logic which states accounts owned by a TA in the territory will not be reassigned; only accounts not owned by a TA
eg: Within the Territory there are 10 accounts.  User A owns 7 of them, User B owns none.  User B would receive the remaining 3 accounts
eg: Within the Territory there are 20 accounts.  User A owns 7 of them, User B owns 2.  User B is first assigned 5 accounts to make the two users equal (each now own 7 accounts) and the remaining 6 are evenly distributed (3 & 3)

This is accomplished by getting the current number of accounts owned by each TA in this Territory (excluding accounts which match Territories with more granularity) and bucketing the TA's by the count in an ascending order
# Ex 1:
User A owns 20 accounts in the territory
User B owns 5 accounts in the territory
User C owns 5 accounts in the territory

This maps to:
{5: {B, C}, 20: {A}}

The code then loops through the users in the first list until either they both own the same number of accounts as the next item in the list (20) or until there are no more mis-owned accounts

# Using the same numbers above if there are 40 mis-owned accounts the map would again start at 
{5: {B, C}, 20: {A}}
Users B & C would each receive 15 accounts to be even with User A, there are now 10 mis-owned accounts and the map is updated to:
{20: {A, B, C}}

Using the same loop logic the 10 remaining mis-owned accounts would be distributed:
User A receives 4 accounts
User B receives 3 accounts
User C receives 3 accounts

The end result is:
User A owns 24 (20 owned, 4 assigned)
User B owns 23 (5 owned, 18 assigned)
User C owns 23 (5 owned, 18 assigned)





## Source project requirements: 
https://docs.google.com/document/d/1KFjEVKu-tTer57okB8FfoqhLygaQzsmJtaKKMIgTtmQ/edit 