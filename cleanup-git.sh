#!/bin/sh
# script to clean-up large .git directories, by telling git that your current commit is the initial commit.
# For that, first checkout to the commit, which you want to make as the initial commit.   Here are the steps
#
# By Kordian W. <code [at] kordy.com>, Aug 2022
#

# update everything
git fetch
git pull

# check out the current code and make it latest-branch
git checkout --orphan latest_branch

# add all the files
git add -A

# Committing the changes
git commit -am 'Initial Commit - Again'

# Deleting the now old master branch
git branch -D master

# renaming this branch as master
git branch -m master

# pushes to master branch
git push -f origin master

# remove the old files
git gc --aggressive --prune=all

# git cleanup
git remote prune originl
git repack
git prune-packed
git reflog expire --expire=1.week.ago
git gc --aggressive

# EOF
