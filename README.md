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


Add a project or branch
------------

The current setup check master branch of every components. You may need to configure a branch (for example xfce4.12)

$ git clone  git://git.xfce.org/xfce/xfce4-panel xfce4-panel.xfce-4-12 -b xfce-4.12
$ cd xfce4-panel.xfce-4-12
$ tx init
$ cd po
# create the .pot source
$ intltool-update --pot --gettext-package  thunar.xfce-4-12
# Edit .pot and change CHARSET to UTF-8 and PACKAGE VERSION to the component name
cd ..
tx set -r xfce4-panel.xfce-4-12 -t PO  --source -l en po/xfce4-panel.xfce-4-12.pot
# This is an existing branch, with already translated lang. So we reimport local lang to transifex. As we don't (yet) use --auto-local, we need to configure every lang manually.
$ for file in $(cd po && ls *.po); do echo ${file} && tx set -r xfce4-panel.xfce-4-12 -l ${file%.po}  po/${file}; done
# And now we push source and translation to transifex resource.
$ tx push -r  xfce4-panel.xfce-4-12 --skip -s -t
# Check the output, some import problems can occurs (mostly language with plural forms (ru, pl) because we reimport old .po, I don't know how to fix this unfortunately, reimporting the one from 'master' branch works most of the time.
