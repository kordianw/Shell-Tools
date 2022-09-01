#!/bin/sh
# script to clean-up large .git directories, by telling git that your current commit is the initial commit.
# For that, first checkout to the commit, which you want to make as the initial commit.   Here are the steps
#
# * By Kordian W. <code [at] kordy.com>, Aug 2022
#

if [ ! -d .git ]; then
  echo "--FATAL: no .git dir - nothing to do!" >&2
fi

# size before
du -sh .git || exit 1

# current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ -z "$BRANCH" ]; then
  echo "--FATAL: couldn't work out the current branch!" >&2
fi

# update everything
git fetch || exit 1
git pull origin $BRANCH || exit 1
git pull || exit 1

# check out the current code and make it latest-branch
git checkout --orphan latest_branch

# add all the files
git add -A

# Committing the changes
git commit -am 'Initial Commit - Again'

# Deleting the now old master branch
git branch -D $BRANCH

# renaming this branch as master
git branch -m $BRANCH

# pushes to master branch
git push -f origin $BRANCH

# remove the old files
git gc --aggressive --prune=all

# git cleanup
git remote prune origin
git repack
git prune-packed
git reflog expire --expire=1.week.ago
git gc --aggressive

# in case we need to reset the local branch to master
git branch --set-upstream-to=origin/$BRANCH $BRANCH

# size after
du -sh .git

# EOF
