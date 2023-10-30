#!/bin/sh

# Exit immediately if a command exits with a non-zero status:
#set -e

local_input_dir="plantuml/"
local_output_dir="output/"

artifacts_repo="https://${WIKI_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git"
artifacts_upload_dir="plantuml_images/"

# Print debug info:
# echo "DEBUG: all variables"
# echo "> all args: $0"
# echo ""
# echo "> local_input_dir:  $local_input_dir"
# echo "> local_output_dir: $local_output_dir"
# echo "> artifacts_repo:       $artifacts_repo"
# echo "> artifacts_upload_dir: $artifacts_upload_dir"
# echo ""
# echo "> INPUT_WIKI_TOKEN: $INPUT_WIKI_TOKEN"
# echo "> "plantuml/":  $"plantuml/""
# echo "> plantuml_images: $plantuml_images"
# echo ""
# echo "> GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
# echo "> GITHUB_WORKSPACE:  $GITHUB_WORKSPACE"
# echo "> GITHUB_ACTOR:      $GITHUB_ACTOR"
# echo "---"

# Set git user settings (this is needed to commit and push):
#git config --global user.name "${GITHUB_ACTOR}"
#git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
 git config --global user.name "GitHub Action 'Render PlantUML'"
 git config --global user.email "github-action@users.noreply.github.com"

# Get paths to all files in input directory:
input_files=$(find "$local_input_dir" -type f -name '*.puml' -print)

echo "=> Downloading PlantUML Java app ..."
sudo apt-get install -y openjdk-8-jre
ver=$(java --version)
echo $ver
wget --quiet -O plantuml.jar https://sourceforge.net/projects/plantuml/files/plantuml.1.2020.15.jar/download

echo "=> Preparing output dir ..."
mkdir -p "$local_output_dir"

echo "Debugging-------------------"
ls

echo "---"

# Run PlantUML for each file path:
echo "=> Starting render process ..."
ORIGINAL_IFS="$IFS"
IFS='
'
for file in $input_files
do 
    fileName=$(basename $file)
    echo "Debugging -------- File name must be .puml"
    echo $fileName
    input_filepath=$file
    output_filepath=$(dirname $(echo $file | sed -e "s@^${local_input_dir}@${local_output_dir}@"))
    echo $output_filepath

    echo " > processing '$input_filepath'"
    java -jar plantuml.jar -charset UTF-8 -output "${GITHUB_WORKSPACE}/${output_filepath}" "${input_filepath}"
done
IFS="$ORIGINAL_IFS"
# source: https://unix.stackexchange.com/questions/9496/looping-through-files-with-spaces-in-the-names

echo "=> Generated files:"
ls -l "${GITHUB_WORKSPACE}/${output_filepath}"

echo "---"

echo "=> Cleaning up possible left-overs from another render step ..."
sudo rm -rf artifacts_repo/

echo "=> Cloning wiki repository ..."
git clone $artifacts_repo "${GITHUB_WORKSPACE}/artifacts_repo"
if [ $? -gt 0 ]; then
    echo "   ERROR: Could not clone repo."
    echo "   Note: you need to initialize the wiki by creating at least one page before you can use this action!"
    exit 1
fi
echo "DEbugging ----------"
pwd
echo "files-------"
ls
echo "=> Moving generated files to /${artifacts_upload_dir} in wiki repo ..."
mkdir -p artifacts_repo/${artifacts_upload_dir}
yes | cp --recursive --force ${local_output_dir} artifacts_repo/${artifacts_upload_dir}

echo "=> Committing artifacts ..."
cd "${GITHUB_WORKSPACE}/artifacts_repo"

git status
git add .
git status
if git commit -m"Auto-generated PlantUML diagrams"; then
    echo "=> Pushing artifacts ..."
    git push
    if [ $? -gt 0 ]; then
    echo "   ERROR: Could not push to repo."
    exit 1
fi
else
    echo "(i) Nothing changed since previous build. The wiki is already up to date and therefore nothing is being pushed."
fi

# Print success message:
echo "=> Done."
echo "---"

# Print embed tags to help the user:
echo "You can use the following tags to embed the generated images into wiki pages:"
output_files=$(find "${GITHUB_WORKSPACE}/artifacts_repo/${artifacts_upload_dir}" -type f -name '*' -print)

ORIGINAL_IFS="$IFS"
IFS='
'
for file in $output_files
do
    filename=$(basename $file)
    echo "[[$(echo ${file} | sed -e "s@^${GITHUB_WORKSPACE}/artifacts_repo@@")|alt=${filename%.*}]]"
done
IFS="$ORIGINAL_IFS"
