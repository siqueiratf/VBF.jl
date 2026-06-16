#!/bin/bash

if [ -z "$1" ]; then
    exit 1
fi

PAPER_NAME=$1

mkdir -p "papers/$PAPER_NAME/input"
mkdir -p "papers/$PAPER_NAME/tests"
touch "papers/$PAPER_NAME/input/paper_info.txt"
touch "papers/$PAPER_NAME/input/$PAPER_NAME.tex"
touch "papers/$PAPER_NAME/Makefile"
touch "papers/$PAPER_NAME/helpers.jl"
touch "papers/$PAPER_NAME/report.jl"



echo "'$PAPER_NAME' CREATED"