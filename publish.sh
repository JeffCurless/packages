#!/usr/bin/env bash
# Publish tested .deb files to the JeffCurless/packages apt repository.
#
#   ./publish.sh              add every .deb in incoming/ (must be a newer version), commit and push
#   ./publish.sh replace      same, but also accept a version that is not newer
#                             (fixes a wrong version number; the existing version is removed first)
#   ./publish.sh list         show what the repository contains
#   ./publish.sh remove PKG.. remove packages, commit and push
#   ./publish.sh prune        discard git history (old .debs) and force-push a single commit
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
DIST=stable

usage() {
    sed -n '4,9p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 1
}

commit_and_push() {
    git add -A dists pool db
    if git diff --cached --quiet; then
        echo "Nothing changed; no commit made."
        return
    fi
    git commit -q -m "$1"
    git push -q
    echo "Pushed. GitHub Pages will update in about a minute; clients then run: sudo apt update"
}

current_version() {
    # Prints the version of $1 currently in the repo, or nothing.
    reprepro -b . list "$DIST" "$1" 2>/dev/null | awk 'NR==1 {print $3}'
}

publish() {
    local replace=$1
    shopt -s nullglob
    local debs=(incoming/*.deb)
    if [ ${#debs[@]} -eq 0 ]; then
        echo "No .deb files in incoming/. Copy tested packages there first."
        exit 0
    fi

    local dups
    dups=$(for deb in "${debs[@]}"; do dpkg-deb -f "$deb" Package; done | sort | uniq -d)
    if [ -n "$dups" ]; then
        echo "incoming/ holds more than one .deb for: $dups" >&2
        echo "Keep only the version you want to publish." >&2
        exit 1
    fi

    local accepted=() summary=() deb pkg ver cur
    for deb in "${debs[@]}"; do
        pkg=$(dpkg-deb -f "$deb" Package)
        ver=$(dpkg-deb -f "$deb" Version)
        cur=$(current_version "$pkg")
        if [ -n "$cur" ] && ! dpkg --compare-versions "$ver" gt "$cur"; then
            if [ "$replace" != yes ]; then
                echo "SKIP $pkg $ver: repository already has $cur (bump the version, or use: $0 replace)."
                continue
            fi
            echo "REPLACE $pkg $cur -> $ver"
            if dpkg --compare-versions "$ver" lt "$cur"; then
                echo "  Note: computers that already installed $cur will not move back to $ver on their own."
                echo "  On those, run: sudo apt install --allow-downgrades $pkg=$ver"
            fi
            reprepro -b . remove "$DIST" "$pkg"
        else
            echo "ADD  $pkg $ver${cur:+ (replaces $cur)}"
        fi
        accepted+=("$deb")
        summary+=("$pkg $ver")
    done

    if [ ${#accepted[@]} -eq 0 ]; then
        echo "Nothing to publish."
        exit 0
    fi

    reprepro -b . includedeb "$DIST" "${accepted[@]}"
    rm -f "${accepted[@]}"

    local msg
    msg="Publish: $(IFS=,; echo "${summary[*]}" | sed 's/,/, /g')"
    commit_and_push "$msg"
}

prune() {
    if [ -n "$(git status --porcelain)" ]; then
        echo "Working tree has uncommitted changes; commit or discard them before pruning." >&2
        git status --short >&2
        exit 1
    fi
    local before
    before=$(du -sh .git | cut -f1)
    echo "This replaces the entire GitHub history of this repo with one commit holding the"
    echo "current files, then force-pushes. Old package versions will be gone for good."
    read -r -p "Type 'prune' to continue: " answer
    [ "$answer" = prune ] || { echo "Cancelled."; exit 1; }

    local branch
    branch=$(git symbolic-ref --short HEAD)
    git checkout -q --orphan prune-tmp
    git add -A
    git commit -q -m "Repository snapshot ($(date +%F)); history pruned"
    git branch -D -q "$branch"
    git branch -m "$branch"
    git push -q --force origin "$branch"
    git reflog expire --expire=now --all
    git gc -q --prune=now
    echo "Pruned. Local .git: $before -> $(du -sh .git | cut -f1). GitHub Pages will rebuild in about a minute."
}

case "${1:-}" in
    "")      publish no ;;
    replace) publish yes ;;
    list)
        reprepro -b . list "$DIST" | awk '{print $2, $3}' | sort -u
        ;;
    remove)
        shift
        [ $# -gt 0 ] || { echo "usage: $0 remove PKG..." >&2; exit 1; }
        reprepro -b . remove "$DIST" "$@"
        commit_and_push "Remove: $*"
        ;;
    prune)   prune ;;
    *)       usage ;;
esac
