#!/bin/bash

hosts_file="$GITHUB_WORKSPACE/.github/hosts.yml"

if [ "$GITHUB_REF" = "" ]; then
    echo "\$GITHUB_REF is not set"
    exit 1
fi

for branch in $(cat "$hosts_file" | shyaml keys); do
    [[ "$GITHUB_REF" = "refs/heads/$branch" ]] && \
    echo "$GITHUB_REF matches refs/heads/$branch" && \
    exit 0
done

# If it reaches here then there have been no matches
echo "$GITHUB_REF does not match with any given branch in 'hosts.yml'"
exit 78