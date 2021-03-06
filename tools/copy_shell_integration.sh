#!/bin/bash

function die {
  echo $1
  exit
}

branch() {
  local output=$(git symbolic-ref -q --short HEAD)
    if [ $? -eq 0 ]; then
        echo "${output}"
    fi
}

set -x

git submodule update --init --remote -- submodules/iTerm2-shell-integration
SUBMODULE=$PWD/submodules/iTerm2-shell-integration
test -d $SUBMODULE || die No $SUBMODULE directory
pushd $SUBMODULE
if [ $(branch) != main ]; then
  die "Not on main. The current branch is $(branch)."
fi
popd

cp $SUBMODULE/source/shell_integration/bash Resources/shell_integration/iterm2_shell_integration.bash
cp $SUBMODULE/source/shell_integration/fish Resources/shell_integration/iterm2_shell_integration.fish
cp $SUBMODULE/source/shell_integration/tcsh Resources/shell_integration/iterm2_shell_integration.tcsh
cp $SUBMODULE/source/shell_integration/zsh  Resources/shell_integration/iterm2_shell_integration.zsh
DEST=$PWD/Resources/utilities

pushd $SUBMODULE/utilities
files=$(find . -type f)
tar cvfz $DEST/utilities.tgz *
echo * > $DEST/utilities-manifest.txt
popd

