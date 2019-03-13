#!/bin/bash
#
# Copyright (c) 2013 Nick Schermer <nick@xfce.org>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA
#

BASE="$HOME/repos"
NOBODY="Anonymous <noreply@xfce.org>"
MINPERC="50"

# direct commands
GIT="/usr/bin/git"
TX="/usr/local/bin/tx"
FIND="/usr/bin/find"
INTLTOOL_UPDATE="/usr/bin/intltool-update"

# refresh log
rm /tmp/txpull.log &> /dev/null

# walk through all the known resources (git clones)
for path in `$FIND $BASE -mindepth 1 -maxdepth 1 -name "*.*" -type d | sort`
do
  resource=`basename "${path}"`
  branchname="${resource//*./}"

  # go into the repo
  cd "${path}" || exit 1

  # find POTFILES.in
  potfilesin=`$FIND  "${path}" -type f -name "POTFILES.in" -print0`
  if [[ -f "${potfilesin}" ]]
  then
    # relative path to the po dir inside the repository
    podir=`dirname "${potfilesin#${path}/}"`
  else
    echo "[${resource}] No POTFILES.in found so could not determn the po directory"
    continue
  fi

  # check if extracted names match
  trackingbranch=`$GIT rev-parse --symbolic-full-name --abbrev-ref @{u}`
  if [[ ("${branchname}" == "master" || "${branchname}" == "xfce-" ) \
        && "${trackingbranch/./-}" != "origin/${branchname}" ]]
  then
    echo "[${resource}] Branch names to not match (${trackingbranch})!"
  fi

  # cleanup repository
  $GIT clean --quiet -xfd -e '.tx/'
  $GIT reset --quiet --hard ${trackingbranch}

  # pull new changes
  $GIT pull --quiet

  # be sure there are no old transifex files left in the tree
  rm -r "${podir}/"*".po.new" ".tx/${resource}/" 2>/dev/null
  mkdir -p ".tx/${resource}"

  # fetch new translations from the transifex server
  $TX pull --skip -r "${resource}" --disable-overwrite --minimum-perc="${MINPERC}" -a 1>>/tmp/txpull.log

  # whether we've made commits
  needspush=0

  # add / update new translations
  for f in `$FIND "${podir}" ".tx/${resource}" -maxdepth 1 -type f -name "*.po.new" -or -type f -name "*_translation" | sort`
  do
    # find the author who made the commit
    #author=`grep -e '^"Last-Translator: .* <.*>\\\\n"$' ${f} | sed -e 's/^"Last-Translator: //' -e 's/\\\\n"$//'`
    author=`grep -e '^"Last-Translator: .* <.*>\\(, [0-9]\\+\\)\\?\\\\n"$' ${f} | sed -e 's/^"Last-Translator: //' -e 's/\\(, [0-9]\\+\\)\\?\\\\n"$//'`
    author=${author:-${NOBODY}}

    # check the translation
    err=`msgfmt --check -o /dev/null "${f}" 2>&1`
    if [[ "$?" -ne "0" ]]
    then
      # generate message
      mailx -s "[Xfce] Msgfmt failed for ${resource}" "${author}" << EOF
Hi,

This is an automatically generated message from the Xfce Transifex bot.
Please do not reply to this message, but use the xfce-i18n mailing list
if you don't know what to do.

Commit of the by you modified translation was not successfull.

msgfmt --check, reported the following issue:

====
${err}
====

Please resolve this issue at transifex.com; for now your translation will
be skipped.

Sincerely,
Xfce

https://mail.xfce.org/mailman/listinfo/xfce-i18n
https://www.transifex.com/xfce/public/
EOF

      # echo "[${resource}] msgfmt check ${f} failed, send message to ${author}"
      # echo "${err}"

      continue
    fi

    # update Project-Id-Version
    projectversion=`pcregrep -o2 "m4_define.*_version_(major|minor|micro)].*(\d)" configure.ac.in | paste -sd "." -`
    sed -i "s/Project-Id-Version:.*/Project-Id-Version: $projectversion\"/" ${f}

    # statistics for in the commit message
    stats=`msgfmt -o /dev/null --statistics "${f}" 2>&1`

    # percentage complete for the commit title
    x=`echo "${stats}" | sed -e 's/[,\.]//g' \
           -e 's/\([0-9]\+\) translated messages\?/tr=\1/' \
           -e 's/\([0-9]\+\) fuzzy translations\?/fz=\1/' \
           -e 's/\([0-9]\+\) untranslated messages\?/ut=\1/'`
    eval "tr=0 fz=0 ut=0 ${x}"
    total=$((${tr} + ${fz} + ${ut}))
    perc=$((100 * ${tr} / ${total}))

    # double check the translated percentage
    if [[ "${perc}" -lt "${MINPERC}" ]]
    then
      # this should not happen, since we've asked tx too
      echo "[${resource}] Not enough translations in ${f} (${perc}%)"
      continue
    elif [[ "${perc}" -eq "100" && "${tr}" -lt "${total}" ]]
    then
      # if (due to rounding) the 100% is not "fully" translated, show 99%
      perc=99
    fi

    # Whether this is a new translation or not
    if [[ "${f}" = ".tx/${resource}/"*"_translation" ]]
    then
      # new filename
      lang=`basename ${f}`
      lang=${lang%_translation}
      targetname="${podir}/${lang}.po"

      # make sure the target does not already exist
      if [[ -f "${targetname}" ]]
      then
        echo "[${resource}] Target for ${targetname} of new translation ${lang} already exists!"
        continue
      fi

      # move the file to the po directory and add it to git
      cp "${f}" "${targetname}"
      $GIT add "${targetname}"

      # add to transifex
      $TX set -r "${resource}" -l "${lang}" "${targetname}" 1>/dev/null

      # commit title
      msgtitle="Add new"
    else
      # target filename
      lang=`basename ${f}`
      lang=${lang%.po.new}
      targetname="${podir}/${lang}.po"
      msgtitle="Update"

      # check if the target exists
      if [[ ! -f "${targetname}" ]]
      then
        echo "[${resource}] Target ${f} does not exist, removed from config"

        # remove from the tx config
        sed "/^trans.${lang} = ${targetname/\//\\/}/d" -i ".tx/config"

        continue
      fi

      # Update file
      cp "${f}" "${targetname}"
    fi

    # commit the update
    $GIT commit -m "I18n: ${msgtitle} translation ${lang} (${perc}%)." \
                -m "${stats}" \
                -m "Transifex (https://www.transifex.com/xfce/public/)." \
                --author "${author}" --quiet "${targetname}" 1> /dev/null

    # update credits in database
    if [[ -f "$HOME/mysql-password" && "${author}" != "${NOBODY}" ]]
    then
      mysql -u transifex -p$(cat $HOME/mysql-password) transifex <<EOF
        INSERT INTO credits(identity,lang_code)
          VALUES ('${author}','${lang}')
          ON DUPLICATE KEY UPDATE n_commits=n_commits+1, last_commit=CURRENT_TIMESTAMP;
EOF
    fi

    # push later
    needspush=1
  done

  # push changes if required
  if [[ "${needspush}" -eq "1" ]]
  then
    err=`$GIT push --quiet 2>&1`
    if [[ "$?" -ne "0" ]]
    then
      echo "[${resource}] git push failed:"
      echo "${err}"
    fi
  fi

  # check if we need to generate the pot file
  potfile=`$FIND  "${podir}" -type f -name "*.pot" -print0`
  if [[ ! -f "${potfile}" ]]
  then
    # generate a new potfile
    pushd "${podir}" 1>/dev/null
    err=`$INTLTOOL_UPDATE --pot --gettext-package "${resource}" 2>&1`
    # We force the CHARSET to UTF-8 to avoid gettext error on compilation...
    sed -i 's/^"Content-Type: text\/plain; charset=CHARSET\\n"$/"Content-Type: text\/plain; charset=UTF-8\\n"/' ${resource}.pot
    popd 1>/dev/null

    # check if the new file exists
    potfile="${podir}/${resource}.pot"
    if [[ ! -f "${potfile}" ]]
    then
      # generate message
      mailx -s "[Xfce] Intltool-update failed for ${resource}" "infra[at]xfce.org" << EOF
Hi,

This is an automatically generated message from the Xfce Transifex bot.
Please do not reply to this message.

intltool-update --pot, reported the following issue:

====
${err}
====

Please resolve this issue in the repository.

Sincerely,
Xfce
EOF

      echo "[${resource}] Failed to generate POT file."
      continue
    fi
  fi

  # check if the potfile requires an update
  potcache=".tx/${resource}.pot"
  count=`msgcat -u "${potcache}" "${potfile}" 2>&1 | wc -c`
  if [[ "${count}" -gt "0" ]]
  then
    # make sure the new po file is set
    $TX set -r "${resource}" --source -l en "${potfile}" 1>/dev/null

    # push the new translation to transifex.com
    $TX push -r "${resource}" --no-interactive --source 1>/dev/null

    # updated the cached pot file
    cp "${potfile}" "${potcache}"

    # to avoid updating all the po files next round, touch all files
    touch --no-create "${podir}/"*".po"
  fi
done
