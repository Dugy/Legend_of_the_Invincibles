Legend of the Invincibles
==============

Description
--------------
*Legend of the Invincibles* is an add-on campaign for the game *Battle for Wesnoth*. It adds a massive campaign, about 200 scenarios long. The campaign has largely tweaked game mechanics, mainly expanding the RPG part of the game.

Other information
--------------
The author of this campaign is Dugi (due to name uniqueness, the name is spelled as Dugy on GitHub). The address of the git repository is https://github.com/Dugy/Legend_of_the_Invincibles. The forum thread discussing the campaign is at https://forums.wesnoth.org/viewtopic.php?f=8&t=32384. If you wish to discuss anything, go there.

Usage
--------------
The add-on is usually downloaded from the game's add-on server. If you wish to use the version from GitHub, look at https://wiki.wesnoth.org/EditingWesnoth to see how to use it.

Code style
--------------
Lua code uses snake case and tab indentation. The breaking of long lines is not decided on.

WML code uses the generally recommended code style, snake case for variable names, four spaces for indentation.

Its usage of space indentation bears no advantage over tabs, but increases file size and is inconsistent with automatically generated and indented code by the game engine (that uses tabs). If you want to use tabs instead, you can have git filter the code for you, on your local repository only:

* create a file `git/info/attributes` containing `*.cfg filter=tabspace`
* use command `git config filter.tabspace.smudge 'unexpand --tabs=4 --first-only'`
* use command `git config filter.tabspace.clean 'expand --tabs=4 --initial'`
* delete all files of type `.cfg` in the repository and use `git reset --hard`
* edit the editorconfig file and untrack it `git update-index --assume-unchanged .editorconfig`

Enabling spinoffs
--------------
Wesnoth will not look for add-ons within an add-on, so in order to get it running, you need to create links in the add-ons folder to these. On Windows, you can make links simply by right clicking the file and choosing _Make shortcut._ On Linux, this option might not be present in the file manager, so you have to navigate into the add-ons folder and make commands like `ln -s Legend_of_the_Invincibles/spinoffs/Affably_Evil/ Affably_evil`.
