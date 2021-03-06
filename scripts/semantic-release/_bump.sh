#!/bin/sh

default()
{
  # Add paths to env (non-Travis build)
  if [ -z "$TRAVIS" ]; then
    PATH=/usr/local/bin:/usr/bin:/bin:$PATH
    export PATH
  fi

  SCRIPT=`basename $0`
  SCRIPT_DIR=`dirname $0`
  SCRIPT_DIR=`cd $SCRIPT_DIR; pwd`

  . $SCRIPT_DIR/../_env.sh
  . $SCRIPT_DIR/../_common.sh
  . $SCRIPT_DIR/_common.sh

  BUILD_DIR=$TRAVIS_BUILD_DIR
}

# Bump version number in bower.json
#
bump_bower()
{
  echo "*** Bumping version in $BOWER_JSON to $VERSION"
  cd $BUILD_DIR

  if [ ! -s "$BOWER_JSON" ]; then
    return
  fi

  if [ -n "$PTNFLY" ]; then
    sed "s|\"version\":.*|\"version\": \"$VERSION\",|" $BOWER_JSON > $BOWER_JSON.tmp
  elif [ -n "$PTNFLY_ANGULAR" ]; then
    sed "s|\"version\":.*|\"version\": \"$VERSION\",|" $BOWER_JSON > $BOWER_JSON.tmp
  fi
  check $? "Version bump failure"

  if [ -s "$BOWER_JSON.tmp" ]; then
    mv $BOWER_JSON.tmp $BOWER_JSON
    check $? "File move failure"
  fi
}

# Bump version number in JavaScript
#
bump_js()
{
  echo "*** Bumping version in $PTNFLY_SETTINGS_JS to $VERSION"
  cd $BUILD_DIR

  if [ ! -s "$PTNFLY_SETTINGS_JS" ]; then
    return
  fi

  if [ -n "$PTNFLY" ]; then
    sed "s|version:.*|version: \"$VERSION\"|" $PTNFLY_SETTINGS_JS > $PTNFLY_SETTINGS_JS.tmp
    check $? "Version bump failure"

    mv $PTNFLY_SETTINGS_JS.tmp $PTNFLY_SETTINGS_JS
    check $? "File move failure"
  fi
}

# Check prerequisites before continuing
#
prereqs()
{
  merge_prereqs

  if [ ! -s "$PACKAGE_JSON" -o ! -s "$BOWER_JSON" ]; then
    echo "*** Cannot locate $PACKAGE_JSON or $BOWER_JSON. Do not bump!"
    exit 1
  fi

  # Get version generated by 'semantic-release pre'
  VERSION=`grep '"version"' $PACKAGE_JSON | \
    awk -F':' '{print $2}' | \
    sed 's|\"||g' | \
    sed 's|,||g' | \
    sed 's| *||g'`

  BOWER_VERSION=`grep '"version"' $BOWER_JSON | \
    awk -F':' '{print $2}' | \
    sed 's|\"||g' | \
    sed 's|,||g' | \
    sed 's| *||g'`

  echo "*** Found $PACKAGE_JSON version number: $VERSION"
  echo "*** Found $BOWER_JSON version number: $BOWER_VERSION"

  if [ "$VERSION" = "$BOWER_VERSION" ]; then
    echo "*** The $PACKAGE_JSON and $BOWER_JSON versions are the same. Do not bump!"
    exit 0
  fi
}

# Publish branch
#
publish_branch()
{
  sh -x $SCRIPT_DIR/_publish-branch.sh -c
  check $? "Publish failure"
}

# Set indicator to ensure 'npm publish' is not run until following master-dist build
#
skip_npm_publish()
{
  echo "*** Creating $SKIP_NPM_PUBLISH_FILE"
  cd $BUILD_DIR

  touch $SKIP_NPM_PUBLISH_FILE
  check $? "Touch file failure"
}

usage()
{
cat <<- EEOOFF

    This script will bump version numbers that semantic release does not handle

    For PatternFly, the version number in $PTNFLY_SETTINGS_JS is bumped. For PatternFly and Angular PatternFly, the
    version number in $BOWER_JSON is bumped.

    sh [-x] $SCRIPT [-h] -a|p

    Example: sh $SCRIPT -p

    OPTIONS:
    h       Display this message (default)
    a       Angular PatternFly
    p       PatternFly

EEOOFF
}

verify()
{
  sh -x $SCRIPT_DIR/_verify.sh $SWITCH
  check $? "Verify failure"
}

# main()
{
  default

  if [ "$#" -eq 0 ]; then
    usage
    exit 1
  fi

  while getopts hap c; do
    case $c in
      h) usage; exit 0;;
      a) PTNFLY_ANGULAR=1;
         SWITCH=-a;;
      p) PTNFLY=1;
         SWITCH=-p;;
      \?) usage; exit 1;;
    esac
  done

  prereqs
  bump_bower
  bump_js
  verify
  publish_branch
  skip_npm_publish
}
