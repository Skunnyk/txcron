txcron
======

Cronjob script to auto-magically push new/updated [transifex.com](http://transifex.com) translations to git repositories.

The script is created for the Xfce Desktop Environment to automate po file updates from translators to the upstream repositories, without intervention of developers. It also checks if there are new pot files needed for the translators, so code and transifex.com are always in-sync.

Setup
-----

Setup if fairly easy, if walks a directory tree located in *$BASE* where each folder has the layout *$RESOURCE.$PROJECT*, corresponding with the project and resource name on the Transifex website. This directory needs to be property initialized and has first po push (it never pushes translations) with the **tx** utility, the script does not do that.

It also assumes the user under which the script is executed has read/write permissions to the git repository, most likely using pubkeys.

What is does
------------
* Reset and pull the tracking branch of the repo.
* Pull new transifex translations.
* Update or add new translations if modified, make nice commit message.
* Regenerate pot file if not found.
* Push new pot file if required.

MySQL
-----
For credit purposes it can also maintain a list of authors. For that create a user and database as defined in the .sql file and put the password in *$HOME/mysql-password*. It will then count commits per-user/language and maintain the last timestamp. This can for example be user to add translators credits to the code with a moving window of the last year.
