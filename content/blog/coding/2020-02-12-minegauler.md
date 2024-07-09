---
.title = "Minegauler",
.date = @date("2020-07-06"),
.author = "Lewis Gaul",
.layout = "blog_post.html",
.tags = ["python", "minesweeper", "gui"],
---


See the [GitHub repo](https://github.com/LewisGaul/minegauler), or try it out by [downloading from here](https://github.com/LewisGaul/minegauler/releases).


## History

When I was younger I used to play a lot of the classic Minesweeper game (according to ['The Authoritative Minesweeper'](http://www.minesweeper.info/countryranking.html?country=186) I'm ranked 49 in the UK ;)). Sometimes while playing I'd feel like I was on track for setting a new personal best before accidentally clicking a mine or losing in a 50/50 corner. I found myself wanting to be able to get a prediction for my final time based on the speed I'd been going and the number of clicks that remained. In my second year at university I decided to try to implement that.

I'd been doing a few bits of Python for a number of years before university, almost entirely self-teaching using Project Euler puzzles, personal mathematical curiosities and implementations of basic card games. My initial intention with the Minesweeper project was to implement a GUI that allowed me to easily input the state of a Minesweeper board for a game that I'd lost, and for the program to then tell me what percentage of the way through I was (in terms of clicks required to complete the game, which is nontrivial to work out without a computer). From this I would be able to get a prediction for my completion time, and I could be extra frustrated at having lost to a silly mistake!


## Early Implementation

Very early in my implementation of the Minesweeper logic, I realised that the actual gameplay logic was quite simple to program in, and would make it easier to manually test things were working as expected (using a command line interface at this point, rather than graphical). I surprised myself in being able to produce a playable Minesweeper game fairly quickly, and felt very pleased to have created by first GUI application. I did then focus on the ability to enter a partially completed board to satisfy the feature I'd initially wanted (it turned out none of my seemingly good partial times were actually as good as they seemed...), but soon became addicted to dreaming up new exotic game modes and other features, while also occasionally sinking some time into playing my new invention!

I spent a huge amount of time on the project in that year, and managed to get quite an impressive list of features working. I also gave a 20-minute talk about the project in my third year of university at the science and technology conference *Inscite*. A list of features is as follows:
 - Option of multiple mines being allowed per cell
 - Option of having more than one life
 - Option of being able to drag and click to select cells rather than click each one individually
 - Option of different 'detection' modes - the numbers would correspond to something other than the surrounding 8 cells
 - Custom board sizes (plus a new 'master' size of 30*30)
 - Highscores
 - Probability calculations based on the state of the board
 - Auto-flag and auto-click (solver)
 - Create and play custom boards
 - Change the size of the buttons
 - Customise the button images
 - Get the current board info, including percentage completed and predicted completion time


## The Rewrites

Eventually I found myself with less time and interest to keep up my previous rate of work. I think it was in my fourth year at university that I decided to put it up on GitHub to link on my CV, as I was starting to think about applying for jobs/internships. At the time I was overly protective of my work, and I ended up cutting out most of the features of the code I was open-sourcing, while giving the project a bit of a rewrite. This ended up setting the tone for the project from then onwards - I've now rewritten it multiple times with some of the following major changes:
 - Cut out most features and publish to GitHub
 - Remove the use of numpy to reduce the size of the application
 - Rewrite in Python 3 and using PyQt5 rather than Tkinter
 - Pull apart some of my spaghetti code, with particular focus on separating the backend and frontend

At the end of 2019 I made a big push to getting the latest version up to scratch with the feature-set my 2015 version had, thanks to some encouragement from my brother! This all started by bringing back local highscores (this time using a SQLite database) - from there I added back in lots of the other features, and even added a server side as a first move towards online highscores! Online highscores are currently available in a programmatic form at <http://minegauler.lewisgaul.co.uk/api/v1/highscores>. The main features I haven't yet reimplemented are board probabilities, custom number of lives, and custom 'detection' (how close mines have to be to a cell for the numbers to count them).

This month I finally felt happy enough with the state of the project to do my first major release in years - [v4.0.4](https://github.com/LewisGaul/minegauler/releases/tag/v4.0.4)! There are still some bugs to iron out, but I think things are in a good place. The state of the project is also much better tracked these days using the GitHub repo (e.g. [issues](https://github.com/LewisGaul/minegauler/issues), [changelog](https://github.com/LewisGaul/minegauler/blob/master/CHANGELOG.md), [code coverage](https://codecov.io/gh/LewisGaul/minegauler/)...).

These days I have a fraction of the time that I had over the holidays while I was at university, so progress is generally slower! I have a number of new features I'd like to implement one day to try them out:
 - Have right-clicks split a cell into 4 rather than flagging the cell (the board would initially have 4 times fewer cells than normal)
 - Rules randomiser, e.g. numbers '1' and '2' are swapped - the aim is to work out which rules have changed in as few losses as possible
 - Playing against the computer (set it to go at a certain speed and play in a separate window)
 - Competing against other players by being presented with the same boards
 - Infinite board and infinite lives - get scored on your overall speed and number of lives lost in a time period


## Get in Contact!

Please feel free to get in touch on <minegauler@gmail.com> if you tried it out and have any thoughts, or if you have a feature request, or if you feel like working with me to improve my latest version!
