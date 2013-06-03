#!/bin/sh
set -e
git checkout gh-pages
ldoc .
git status
git commit -a -m "updated docs"
git push origin gh-pages
