function dot {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )
    git --git-dir="$HOME/projects/win-dot-bare" --work-tree="$HOME" @Args
}
