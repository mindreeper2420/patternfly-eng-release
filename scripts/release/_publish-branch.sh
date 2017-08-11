#!/usr/bin/env bash

#
# Note: When run against a tag, TRAVIS_BRANCH won't equal the branch name "master", but whatever was given as
# the tag name (e.g., _release-v3.15.0). To ensure we push to the correct branch, don't use TRAVIS_BRANCH here.
#

default()
{
  SCRIPT=`basename $0`
  SCRIPT_DIR=`dirname $0`
  SCRIPT_DIR=`cd $SCRIPT_DIR; pwd`

  . $SCRIPT_DIR/../_env.sh
  . $SCRIPT_DIR/../_common.sh
  . $SCRIPT_DIR/_common.sh

  BRANCH=$RELEASE_BRANCH
  BRANCH_DIST=$RELEASE_DIST_BRANCH
  BUILD_DIR=$TRAVIS_BUILD_DIR
}

# Push version bump and generated files to dist branch for tagging release.
#
# $1: Remote branch
# $2: Local branch
push_dist()
{
  echo "*** Pushing to dist branch: $1"
  cd $BUILD_DIR

  git checkout $TRAVIS_BRANCH-local

  # Commit generated files
  git add dist --force
  if [ -d "dist-demo" ]; then
    git add dist-demo --force
  fi
  git commit -m "Added files generated by Travis build"
  check $? "git commit failure"

  # Push to dist branch
  EXISTING=`git ls-remote --heads https://github.com/$TRAVIS_REPO_SLUG.git $1`

  if [ -n "$EXISTING" ]; then
    git fetch upstream $1:$2 # <remote-branch>:<local-branch>
    git checkout $2
    git merge -X theirs $TRAVIS_BRANCH-local --no-edit --ff
    check $? "git merge failure"

    git push upstream $2 -v
  else
    git push upstream $TRAVIS_BRANCH-local:$2 -v # <local-branch>:<remote-branch>
  fi
  check $? "git push failure"
}

# Push version bump changes to master branch
#
# $1: Remote branch
# $2: Local branch
push_master()
{
  echo "*** Pushing to master branch: $1"
  cd $BUILD_DIR

  # Note: Changes are already committed by release script prior to bower install verification

  # Merge master branch
  git fetch upstream $1:$2 # <remote-branch>:<local-branch>
  git checkout $2
  git merge -X theirs $TRAVIS_BRANCH-local --no-edit --ff
  check $? "git merge failure"

  # Push to master
  git push upstream $2:$1 -v # <local-branch>:<remote-branch>
  check $? "git push failure"
}

usage()
{
cat <<- EEOOFF

    This script will publish generated files to GitHub.

    Publish master before dist branch to avoid committing generated files to master.

    Note: Intended for use with Travis only.

    sh [-x] $SCRIPT [-h|b] -d|m

    Example: sh $SCRIPT -m

    OPTIONS:
    h       Display this message (default)
    d       Push version bump and generated files to dist branch
    m       Push version bump to master branch

    SPECIAL OPTIONS:
    b       The branch to publish (e.g., $NEXT_BRANCH)

EEOOFF
}

# main()
{
  default

  if [ "$#" -eq 0 ]; then
    usage
    exit 1
  fi

  while getopts hb:dm c; do
    case $c in
      h) usage; exit 0;;
      b) BRANCH=$OPTARG; BRANCH_DIST=$OPTARG;;
      d) PUSH_DIST=1;;
      m) PUSH_MASTER=1;;
      \?) usage; exit 1;;
    esac
  done

  if [ -n "$PUSH_MASTER" -a -n "$PUSH_DIST" -a "$BRANCH" = "$BRANCH_DIST" ]; then
    check 1 "Cannot use same name for both master and dist branches"
  fi

  git_setup

  # Push version bump to master branch
  if [ -n "$PUSH_MASTER" ]; then
    push_master $BRANCH $BRANCH
  fi

  # Push version bump and generated files to dist branch
  if [ -n "$PUSH_DIST" ]; then
    push_dist $BRANCH_DIST $BRANCH_DIST
  fi
}
