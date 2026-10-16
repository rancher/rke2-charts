NR == FNR {
    columns[$1] = $2
    next
}

{
    text = $0
    sub(/\r$/, "", text)
    match(text, /[^ \t]/)
    column = RSTART

    if (FNR in columns) {
        if (column != columns[FNR] || text !~ /^ *description:([ \t]|$)/) {
            printf "error: %s:%d: description must be a standalone block mapping entry\n", FILENAME, FNR > "/dev/stderr"
            exit 1
        }
        indent = column
        value = text
        sub(/^ *description:[ \t]*/, "", value)
        scalar_comments = value ~ /^[|>"']/
        removing = 1
        printf "%s", pending
        pending = ""
    } else if (removing && !column) {
        pending = pending $0 RT
    } else if (removing && column) {
        if (column <= indent) {
            removing = 0
        }
        if (!removing || (!scalar_comments && text ~ /^ *#/)) {
            printf "%s", pending
            printf "%s%s", $0, RT
        }
        pending = ""
    } else {
        printf "%s%s", $0, RT
    }
}

END {
    printf "%s", pending
}
