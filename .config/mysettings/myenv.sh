#!/usr/bin/env bash

# set vi mode in bash
set -o vi

# set vi mode in zsh
# bindkey -v

export BROWSER=qutebrowser

# aliases
alias googler="googler -l=en_US"
alias dotfiles="/usr/bin/git --git-dir=$HOME/dotfiles --work-tree=$HOME"

# Color scheme for googler
export GOOGLER_COLORS=GGPmgy

# Color scheme for mc
export MC_SKIN=/home/dg/.config/mc/skins/myskin.ini

fortune -a | cowsay
