#!/bin/bash


#!/bin/bash

# example usage: apply.sh wip-rgw-foo master rgw

[ "$3" == "" ] && echo "Usage: $0 <feature-branch> <master-branch> <commit-id>" && exit 1

feature_branch=$1
master_branch=$2
cid=`git rev-parse $3`
commit_id=${cid:0:11}
base_commit=`git merge-base $feature_branch $master_branch`

ancestors=""

root=`dirname $0`/$feature_branch

commit_root="$root/commits/feature/$commit_id"

[[ ! -d $root ]] && echo "Need to run init first" && exit 1

line_code() { 
        sep=") "
        x="${1%%$sep*}"
        [[ "$x" = "$1" ]] && echo $1 && return
        
        i=${#x}
        i=$((i+2))

        echo "${1:i}"
}

is_ancestor() {
        cid=$1

        [[ "$ancestors" =~ "$cid" ]] && return 0

        git merge-base --is-ancestor $cid $base_commit
        [ $? -gt 0 ] && return 1

        ancestors="$ancestors $cid"

        return 0
}

try_apply_commit() {
        # git apply $1
        # return $?
        return 1
}

analize_head_code() {
        cid="${1:0:11}"

        l="${1:12}"

        master_commit_path="$root/commits/master/$cid"
        feature_commit_path="$root/commits/feature/$cid"

        if [ -d "$master_commit_path" ]; then
                status="master  "
        elif [ -d "$feature_commit_path" ]; then
                status="feature "
        else
                is_ancestor $cid && status="old     " || status="new     "
        fi

        echo "$status $cid $l"
}

analize_file() {
        f=$1
        blame_file="$commit_root/analyze/$f"
        mkdir -p `dirname $blame_file`

        git blame $f > "$blame_file"

        in_head=0
        in_feature=0

        while read fline
        do
                lc=$(line_code "$fline")
                
                iline="        $fline"

                f4="${lc::4}"
                if [ "$f4" == "<<<<" ]; then
                        in_head=1
                        in_feature=0
                        echo "$iline"
                        continue
                elif [ "$f4" == "====" ]; then
                        in_head=0
                        in_feature=1
                        echo "$iline"
                        continue
                elif [ "$f4" == ">>>>" ]; then
                        in_head=0
                        in_feature=0
                        echo "$iline"
                        continue
                fi

                if [ $in_head -eq 1 ]; then
                        analize_head_code "$fline"
                fi

        done < "$blame_file"
}

analyze_conflict() {
        apply_diff="$commit_root/apply_diff"

        git diff  > "$apply_diff"

        while read line
        do
                if [ "${line:0:4}" == "diff" ]; then
                        diff_line=$line
                        f=`echo "$line" | awk '{print $NF}'`
                elif [ "${line:0:3}" == "+++" ]; then
                        echo $diff_line
                        analize_file $f
                fi
        done < "$apply_diff"
}


main() {
        if try_apply_commit $commit_id; then
                echo "Success!"
                exit 0
        fi

        analyze_conflict
}


main "$@"
