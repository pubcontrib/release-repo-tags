#!/bin/sh
repo_path=$1
releases_path=$2
verbose=$3

if [ -z "$repo_path" ]
then
    printf "[ERROR] No repo path given.\n"
    exit 1
fi

if [ -z "$releases_path" ]
then
    printf "[ERROR] No releases path given.\n"
    exit 1
fi

syncRepo()
{
    git fetch -ap > /dev/null 2>&1
    git pull > /dev/null 2>&1
    git tag -l --sort=v:refname
}

currentCommit()
{
    git rev-parse HEAD
}

checkoutTag()
{
    tag=$1

    git checkout -b testing "tags/$tag" > /dev/null 2>&1
}

build()
{
    release_path=$1
    commit=$2
    cc=gcc

    # Create a release directory
    mkdir "$release_path"

    # Make the release
    make_path="$release_path/make"
    mkdir "$make_path"
    make CC="$cc" > "$make_path/stdout.txt" 2>"$make_path/stderr.txt"
    printf "%d\n" $? > "$make_path/exitcode.txt"

    # Create a binary archive
    tar -czf "$release_path/binary.tar.gz" AUTHORS LICENSE README.md bin

    # Create a source archive
    tar -czf "$release_path/source.tar.gz" AUTHORS LICENSE README.md src Makefile

    # Test the release
    check_path="$release_path/check"
    mkdir "$check_path"
    make check > "$check_path/stdout.txt" 2>"$check_path/stderr.txt"
    printf "%d\n" $? > "$check_path/exitcode.txt"

    # Clean the release
    clean_path="$release_path/clean"
    mkdir "$clean_path"
    make clean > "$clean_path/stdout.txt" 2>"$clean_path/stderr.txt"
    printf "%d\n" $? > "$clean_path/exitcode.txt"

    # Save artifacts of the build
    printf "%s\n" "$commit" > "$release_path/commit.txt"
    uname=`uname --all`
    printf "%s\n" "$uname" > "$release_path/uname.txt"
    sha256sum=`sha256sum $release_path/binary.tar.gz $release_path/source.tar.gz`
    printf "%s\n" "$sha256sum" > "$release_path/sha256sum.txt"
    date=`date --utc --iso-8601=seconds`
    printf "%s\n" "$date" > "$release_path/date.txt"
    ccversion=`$cc --version`
    printf "%s\n" "$ccversion" > "$release_path/ccversion.txt"
}

cleanupBranch()
{
    git checkout master > /dev/null 2>&1
    git branch -d testing > /dev/null 2>&1
}

debug()
{
    message=$1

    if [ ! -z "$verbose" ]
    then
        printf "%s\n" "$message"
    fi
}

printf "Checking for any new releases...\n"
printf "Tags updated as of %s.\n" "$(date)"

cd "$repo_path"
tags="$(syncRepo)"

for tag in $tags
do
    debug "$tag"

    release_path="$releases_path/$tag"
    release_count=0

    if [ -d "$release_path" ]
    then
        debug "Skipping..."
    else
        checkoutTag "$tag"
        commit="$(currentCommit)"
        build "$release_path" "$commit"
        cleanupBranch
        release_count=$((release_count+1))

        debug "Done"
    fi

done

printf "Released %d versions.\n" $release_count
