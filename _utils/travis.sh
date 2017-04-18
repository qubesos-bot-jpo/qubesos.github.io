#!/bin/bash

set -x
set -e
set -o pipefail

is_pr() {
	test -n "$TRAVIS_PULL_REQUEST" -a false != "$TRAVIS_PULL_REQUEST"
}

cd "$(dirname "$0")/.."

# from https://github.com/gjtorikian/html-proofer
#     When installation speed matters, set NOKOGIRI_USE_SYSTEM_LIBRARIES to
#     true in your environment. This is useful for increasing the speed of
#     your Continuous Integration builds.
export NOKOGIRI_USE_SYSTEM_LIBRARIES=true
gem install github-pages html-proofer

repo_owner=${TRAVIS_REPO_SLUG%%/*}
repo_name=${TRAVIS_REPO_SLUG#*/}

# Use modules of same owner so you can test whole site before proposing PR
git config --file .gitmodules --get-regexp '.*\.url' \
| while read repo url; do
	owner_url="${url/github.com\/[^\/]*\//github.com\/${repo_owner}\/}"
	: url=$url
	: repo_owner=$repo_owner
	: owner_url=$owner_url
	git config --file .gitmodules "$repo" "$owner_url"
done

git submodule update --init --recursive

bundle exec jekyll build

htmlproofer ./_site --disable-external --checks-to-ignore ImageCheck --file-ignore ./_site/video-tours/index.html --url-ignore "/qubes-issues/,https://ftp.qubes-os.org /,https://mirrors.kernel.org /"

if is_pr; then
	echo moving old site
	mv _site ~/old_site

	sub_name=$(git config --file .gitmodules --list | grep -m1 -F -- "$repo_name" | cut -d. -f2)
	sub_path=$(git config --file .gitmodules --get -- "submodule.${sub_name}.path")
	git -C "$sub_path" remote add base "https://github.com/${TRAVIS_REPO_SLUG}"
	git -C "$sub_path" fetch base "pull/${TRAVIS_PULL_REQUEST}/head"
	git -C "$sub_path" checkout FETCH_HEAD
	bundle exec jekyll build

	echo moving new site
	mv _site ~/new_site

	echo diffing
	diff -ur ~/old_site ~/new_site || true
fi
