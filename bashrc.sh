export XDG_CONFIG_HOME=~/.config 
export PATH="~/.local/bin:~/de_config/scripts:$PATH"

shopt -s globstar
shopt -s failglob
# I don't fully understand how the escapes in the echo command work
# TODO see if this takes a long time to execute
PS1='\[\e[34m\]\w\[\e[0m\]$( if branch=$(git branch --show-current 2> /dev/null); then echo '::\\[\\e[32m\\]'$branch'\\[\\e[0m\\]'; fi )\$ \[\e[6 q\]'

export MANPAGER='nvim +Man!'

de() {
    source ~/de_config/bashrc.sh
}
export -f de

alias vim="nvim"
alias v="nvim"

alias g="git"
alias gs="git status --short"
alias gd="git diff --output-indicator-new=' ' --output-indicator-old=' '"
alias gc="git commit"
alias gp="git push"
alias gu="git pull"
alias gl="git log --pretty=custom-short"
alias gb="git branch"
alias gsw="git switch"
gview() {
    if test -z "$1"; then
        echo 'Error: did not supply refspec' >&2
        return 1
    fi
    nvim -c "View $1"
}

alias wip="git commit --no-verify -a -m wip"
# I could make this check whether the previous commit has the message "wip"
alias uwip="git reset HEAD~"
e() {
    awesome-client "launch_editor_in_directory('$(pwd)')"
}
# I don't know why alias s="nvim \"+'0\"" doesn't work on WSL,
# it does on normal ubuntu
alias s="if jobs nvim &> /dev/null; then fg nvim; else nvim \"+:norm'0\"; fi"
alias colemak="xmodmap ~/de_config/colemak"
alias cmk="colemak"
alias qwerty="setxkbmap us"
alias clip="xclip -selection c"
alias down="cd ~/Downloads"
alias ls="ls --color=auto"
alias grep="grep --color=auto"
alias battery='cat /sys/class/power_supply/BAT?/capacity'
alias objdump='objdump -M intel'
alias rust-objdump='rust-objdump -M intel'
alias icat='kitten icat'

# TODO incorporate max_brightness to scale nicely
brightness() {
    echo $1 | sudo tee '/sys/class/backlight/intel_backlight/brightness' > /dev/null
}

TASK_DIR="$HOME/tasks"

# if in tmux session
if [ -n "$TMUX" ]; then
    # taken from https://superuser.com/questions/410017/how-do-i-know-current-tmux-session-name-by-running-tmux-command
    export task=$( tmux display-message -p '#S' )
fi

endat() {
    input=
    while [ "$input" != "$1" ]; do
        read -s -n ${#1} input
    done
}

mksh() {
    if [ -z "$1" ]; then
        echo error: file name not specified
        return 1
    elif [ -a "$1" ]; then
        echo error: file exists
        return 1
    else
        echo '#!/bin/bash' > "$1"
        chmod a+x "$1"
        nvim "$1"
    fi
}

# removes trailing whitespace in the git diff between the worktree and the index
cleanwhitespace() {
    for FILE_LINE in $( git diff --check | rg '(.*):' -or '$1' ); do
        echo removing trailing whitespace from $FILE_LINE
        FILE=$( echo $FILE_LINE | rg '(.*):' -or '$1' )
        LINE=$( echo $FILE_LINE | rg ':(\d+)' -or '$1' )
        sed -i -E -e "${LINE}s/\\s+$//" $FILE
    done
}

switchtask() {
    if ! [[ -n $( cut $TASK_DIR/list.txt -d' ' -f1 | rg $1 ) ]]; then
        echo "no such task in the list"
        return
    fi

    if [ -n "$TMUX" ]; then
        if ! tmux has-session -t $1; then
            tmux new-session -d -s $1
        fi
        tmux switch-client -t $1
    else
        tmux new-session -A -s $1
    fi
}

alias st=switchtask

# notes
alias nt="nvim $TASK_DIR/$task/notes.txt"

# repo in $1
task_worktree() {
    if ! [[ -d "$1/$task" ]]; then
        git -C $1 worktree add $task
    fi
   cd "$1/$task"
}

alias progress="nvim $TASK_DIR/$task/daily_progress.txt"

# $1 is "daily | weekly"
progresscompile() {
    printf "compiled on $(date)\n\n"

    for file in $(find -name $1_progress.txt); do
        # TODO this needs to be changed
        echo "$(basename $file):"
        cat $file
        echo ""
    done

    # rm $PROGRESS_DIR/$1/*
}

# $1 is "daily" | "weekly"
progressreset() {
   rm $(find $TASK_DIR -name $1_progress.txt)
}

progressmove() {
    for task_dir in $TASK_DIR/*; do
        daily_progress=$task_dir/daily_progress.txt
        if [ -a $daily_progress ]; then
            weekly_progress=$task_dir/weekly_progress.txt
            if ! [ -a $weekly_progress ]; then
                printf "$(basename $task_dir) weekly status begun at $(date)\n\n" >> $weekly_progress
            fi
            cat $daily_progress >> $weekly_progress
            nvim $weekly_progress
        fi
    done

    progressreset daily
}

addtask() {
    echo "$1 open" >> $TASK_DIR/list.txt
    mkdir $TASK_DIR/$1
}

nexttask() {
    rg -i -v blocked $TASK_DIR/list.txt | head -n 1 | cut -d' ' -f1
}

block () {
    sed -i "/$1/s/open/blocked/" $TASK_DIR/list.txt
}

unblock () {
    sed -i "/$1/s/blocked/open/" $TASK_DIR/list.txt
}

test -f ~/.system-bashrc.sh && . ~/.system-bashrc.sh
