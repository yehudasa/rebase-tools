#!/bin/bash

# example usage: init.sh wip-rgw-foo master rgw

[ "$2" == "" ] && echo "Usage: $0 <feature-branch> <master-branch> [subdir]" && exit 1

feature_branch=$1
master_branch=$2

root=`dirname $0`/$feature_branch

subdir=$3
commits_diff=$root/commits_diff.txt
commits_root=$root/commits

prepare_workspace() {
        mkdir -p $root
        mkdir -p commits_root
}

add_commit() {
        commit_type=$1
        commit_id=$2
        title="$3"

        # get a longer commit id
        cid=`git rev-parse $commit_id`
        cid=${cid::11}

        echo adding $commit_type commit: $commit_id

        echo "commit=$commit_id"
        echo "title=$title"

        commit_path=$commits_root/$commit_type/$cid
        mkdir -p $commit_path

        diff="$commit_path/diff"

        echo "$title" > "${commit_path}/title"
        git show $cid > "$diff"

}


handle_non_feature_line() {
        line="$1"

        echo $line | grep -e '[0-9]' -e '[a-f]' > /dev/null
        [[ $? -gt 0 ]] && return

        l=`echo $line | sed 's/^[^[:alnum:]]*//g'`

        add_commit "master" "${l::9} " "${l:10}"
}


main() {
        prepare_workspace

        echo "Writing commit diff into $commit_diff"

        git log --left-right --graph --cherry-pick --oneline ${feature_branch}...${master_branch} $subdir > $commits_diff

        # analyze commits_diff
        while read line
        do
                if [ "${line::1}" == "<" ]; then
                        add_commit "feature" "${line:2:10}" "${line:13}" # <commit_id> <commit_message>
                else
                        handle_non_feature_line "$line"
                fi
        done < $commits_diff
}

main "$@"
