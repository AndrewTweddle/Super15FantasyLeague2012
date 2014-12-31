# Super 15 Fantasy League: 2012

## Overview

This project is a cleaned up version of the code I used to plan my Fantasy League team for the Super 15 Rugby tournament in 2012. 

The fantasy league is an annual competition run by [Ultimate Dream Teams](http://ultimatedreamteams.com/site/current-games/item/20-super-rugby-fantasy-league.html).
A friend introduced me to the competition in 2008, and I have competed 4 times since then.

Initially I tried to play the game using my own intuition. This didn't work so well. 
My focus later shifted to using Mathematical Optimization techniques to code an algorithm to play the game for me. 
This was a fun way to return to my roots in Operations Research and also get experience with new programming languages and techniques at the same time.

If you are competing in a Fantasy League and want some ideas on how to automate your strategy, then this project may be useful to you.


# Technologies used

The project uses the following programming languages and technologies:
* PowerShell for the scripting glue and some data munging
* The R programming language to create the statistical model of player and team scores
* C# to generate an LPS file to pass to lpsolve
* LPSolve as the linear programming tool to generate an optimal schedule of player transfers for a number of rounds ahead
* CSV files for the data inputs and outputs to each step of the process
* The Jet OLEDB drivers to read the CSV files into C#


# Documentation

## The sequence of planning steps

The [docs/SequenceOfPlanningATeamAndRecordingResults.txt](https://github.com/AndrewTweddle/Super15FantasyLeague2012/blob/master/docs/SequenceOfPlanningATeamAndRecordingResults.txt) 
file provides an overview of the sequence of steps in both the planning and recording processes.

Note:   I haven't checked that the document is up to date, but at a glance it looks roughly correct.

Update: The optimization steps at the end look like they need updating.

## The main Powershell scripts

Here is [the master Powershell script](https://github.com/AndrewTweddle/Super15FantasyLeague2012/blob/master/PowershellScripts/Prepare-UpcomingRound.ps1) 
for planning the team for an upcoming round.

Here is [the master Powershell script](https://github.com/AndrewTweddle/Super15FantasyLeague2012/blob/master/PowershellScripts/Record-RoundResults.ps1) for recording the results after a round is completed.

## The main R scripts

Here is [the R script to forecast match results](https://github.com/AndrewTweddle/Super15FantasyLeague2012/blob/master/RScripts/ForecastMatchResults.R).

Here is [the R script to forecast players' points](https://github.com/AndrewTweddle/Super15FantasyLeague2012/blob/master/RScripts/ForecastPlayerScores.r)
 for all remaining rounds.

## Generating the LPS linear programming model

The Generate() method in the [LPSModelGenerator.cs](https://github.com/AndrewTweddle/Super15FantasyLeague2012/blob/master/CSharp/Optimization/LPSModelGenerator.cs) 
file provides a readable overview of the steps in constructing the Linear Programming model.

## Running the Powershell scripts

To be able to run the Powershell scripts, you should do the following:

1. Ensure that scripts can be run from Powershell (Powershell is locked down by default):
  1. Open up Windows Powershell *as an administrator*
  2. Run the command `Set-ExecutionPolicy RemoteSigned` (this allows local .ps1 script files to be run without being cryptographically signed)
2. Import the prompting module (NB: this is a utility to step a user through a hierarchy of manual or automated steps - I originally wrote it to facilitate automated deployment of software updates at work)
  1. Either copy the PromptingFunctions module to the WindowsPowershell directory under your "My Documents" folder:
    1. Copy the WindowsPowershell/Modules/PromptingFunctions folder under C:\Users\<YourUserName>\Documents\WindowsPowershell\Modules
    2. Open up a new Powershell session.
    3. Load the module with `Import-Module PromptingFunctions`
  2. Or import the module using the full path to the WindowsPowershell/Modules/PromptingFunctions folder:
    1. `Import-Module /path/to/WindowsPowershell/Modules/PromptingFunctions`
3. Create a virtual drive FL:\ and variable `$FL` pointing to the root path of the FantasyLeague2012 working directory:
  1. Create the variable as follows: `new-variable -Name 'FL' -Value '/path/to/working/copy' -scope Global`
  2. Create a virtual drive pointing to the path: `new-PSDrive -name 'FL' filesystem -root '/path/to/working/copy' -scope Global | out-null`
  3. Test this by checking the contents of the working copy: `dir fl:\`
4. Consider putting the code in steps 2 and 3 into your Windows Powershell profile:
  1. The $profile variable gives the path to this file.
  2. Check if this file exists using `test-path $profile`
  3. If it doesn't exist, create it using `new-item -itemType 'File' -path $profile`
  4. Edit it using `notepad $profile` (or another editor)

# How successful was the model?

## Performance compared to 2011

With this model I came 2 444th, which placed me in the 91.4th percentile of all entrants.

This is fairly good. However I did far better in 2011, where I came in the 99.4th percentile (183rd out of 30 355 contestants).

## What was my approach in 2011?

In 2011, I used [a massive spreadsheet](https://github.com/AndrewTweddle/Super15FantasyLeague2012/tree/master/Spreadsheets/2011) to forecast player and team-based scores for each future round.
* I started off using the bookies' pre-season odds on the tournament winner to estimate the probabilities of a team winning a particular match. 
* I added a fixed linear adjustment to each probability to cater for home advantage.
  A sigmoid function (such as the logistic curve) would have worked better, but this was good enough (even though it occasionally creating impossible probabilities).
* I adjusted these probabilities after each round based on the actual results in the match.
* I used these probabilities to estimate the points earned by a player for being part of a winning team.
* I used the spreadsheet to track the number of individual points earned by a player in the fantasy league over the previous and current season to date.
* I used a geometrically weighted average of these points, to estimate a player's non-team related points per match.

Finally I used a C# program to:
* extract various input data and statistical forecasts from the spreadsheet
* generate a Linear Programming file in LPS format to represent the optimization problem
* pass the LPS file to the Open Source lpsolve application
* parse the outputs
* generate a text file of team selections to copy and paste back into the spreadsheet

After each round of the Super 15 competition:
* I  captured certain results into the spreadsheet.
* I wrote a script which scraped the latest scores for all players from the Fantasy League web site (using a very hairy regular expression) and pasted this data into the spreadsheet.
* I re-ran the Excel calculations (switched off by default otherwise they would take a minute to run each time a cell was changed!).
* This would update my statistical model for the coming rounds.

## What did I do differently in 2012?

The weakness of my model in 2011 was that the estimates of individual player scores was independent of who the opposition was.
In reality, players will get a lot more points against teams with weak defence (such as the Cheetahs in 2011, who often scored a lot of tries but conceded even more).
And they will get a lot less points against a defensively strong team (such as the Stormers in 2012, who scored very few tries but hardly conceded any either).

In 2012 I wanted to incorporate these sorts of effects into the model.
So I built a multiplicative model where each team would have an attack and defence factor both at home and away from home.
The home team's score in each match would be predicted from the home team's attack factor at home and the away team's defence factor away from home.
The away team's score would be based on their attack factor away from home, and the home team's defence factor at home.

I used this model to estimate the scores of each team in each match, not just the probability of a win or loss as I did in 2011.

I made some fairly minor modifications to the C# program. But for the most part the linear programming optimizer was very similar to 2011.

I also used the PowerShell scripting language for guiding me through 
the rather complicated process of capturing various data, 
running statistical forecasts in R, running the optimization model, 
checking chosen teams against known teamsheets, and so forth.
In addition PowerShell proved to be a great tool for data munging.

## Why did I do worse in 2012?

My estimation model in 2011 was crude but simple.

Given the limited amount of data available for building a model, simplicity is essential.
This is something I only became aware of much later, after following Caltech professor Yaser Abu-Mostafa's 
excellent [Machine Learning course](https://www.youtube.com/playlist?list=PLD63A284B7615313A) on YouTube.

Abu-Mostafa gave the rough rule of thumb that you need about ten times as much data as the number of parameters in your model.

I only had around 120 data points at the start of the season (the round robin matches from the previous season).
So I should have been aiming for around 12 parameters for the 15 teams.

In 2011 I was in the right ballpark, with 15 parameters in my team model:
* the adjustment for home ground advantage,
* a probability of winning for each of the 15 teams,
* less one, since the probabilities can be treated as "strength factors" and scaled up so that one team's strength factor becomes 1.0

But in 2012, I had 4 parameters for each of the 15 teams (attack and defence factors at home and away from home).
And I was fitting a negative binomial distribution, which has extra flexibility to choose values for the parameters.

So I had made the very common mistake of building a model which was "over-fitting" the data.

In other words, the model was parrot learning past data rather than building generalized knowledge that can be used for predicting future data.

## How to fix the model

Either the model must be made dramatically simpler or the amount of data must be increased significantly.

The amount of data could be increased by using many more seasons of historical data to build a model.
I suspect this will be problematic, since it assumes a high degree of team continuity from season to season.
While some teams do display this level of consistency, there are often dramatic slumps (as experienced by the Auckland Blues in 2012) and turnarounds in fortune (such as with the Chiefs in 2012).

The other approach is to make the model drastically simpler.
One could go back to having a single strength factor per team and a home ground adjustment, as was done in 2011.
My spreadsheet model in 2011 was very crude, and in some ways just plain wrong (but good enough for my needs at the time).
There might be significant improvements from using R to build the statistical model instead.

Additionally, it might be worth investigating types of models which are less sensitive to limited amounts of data.
I recently purchased the [Applied Predictive Modeling](http://appliedpredictivemodeling.com/) book by Max Kuhn and Kjell Johnson.
This is one of the aspects which the book promises to give insight into.
However I've only just started reading the book, so I don't know enough yet to be able to give any kind of advice.

# Status of the project

At this point I have uploaded the C# application and all of the R and Powershell scripts.

I still need to:
* Add any other documentation to improve accessibility
* Add the various data files that were inputs and outputs to various steps in the process
* Change the C# Program.cs file to use a relative path not a hard-coded path
* Modify the R scripts which contain hard-coded paths to c:\FantasyLeague
* Test that any other outstanding dependencies, such as hard-coded file paths, have been "virtualized"
* Test that my refactorings have not broken the application
