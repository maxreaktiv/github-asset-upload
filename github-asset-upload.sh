#!/bin/sh

# GitHub REST API ref: https://docs.github.com/en/rest/reference/repos#releases
# Author: https://gist.github.com/thomsmed/a9538cfb6f156b7966f27aea3c14071e
#
# Expects the following arguments:
#
# REPOSITORY - GitHub Repository
# TOKEN - GitHub token
# RELEASE_ID - ID of GitHub Release
# FILE - File to upload (file path)
#
# Example:
#   Get release-id:
#     curl -s -H "Authorization: token <github-token>" https://api.github.com/repos/<github-user>/<some-repo>/releases | jq '.[0].id'
#   Upload file
#     ./github-asset-upload.sh "github-user/some-repo" "<github-token>" "<release-id>" "path/to/file"

REPOSITORY=$1
TOKEN=$2
RELEASE_ID=$3
FILE=$4

FILENAME=$(basename $FILE)
FILETYPE=$(file -b --mime-type $FILE)

echo ""
echo "Repository: $REPOSITORY"
echo "Release Id: $RELEASE_ID"
echo "File:"
echo "- Path: $FILE"
echo "- Filename: $FILENAME"
echo "- Filetype: $FILETYPE"

echo ""
if [ -z ${REPOSITORY+x} ] || [ -z ${TOKEN+x} ] || [ -z ${RELEASE_ID+x} ] || [ -z ${FILE+x} ]; then
  echo "Not enough arguments provided to upload asset, aborting!"
  exit 1
fi

upload_asset () {
  echo ""
  echo "Uploading asset ($FILENAME) to GitHub Release..."

  local STATUS_CODE=$(
    curl -sL -o /dev/null -w '%{http_code}' \
      -X POST \
      --header "Accept: application/vnd.github.v3+json" \
      --header "Authorization: token $TOKEN" \
      --header "Content-Type: $FILETYPE" \
      --data-binary @$FILE \
      "https://uploads.github.com/repos/$REPOSITORY/releases/$RELEASE_ID/assets?name=$FILENAME"
  )

  if [ $STATUS_CODE = 201 ]; then
    echo "SUCCESS: Asset ($FILENAME) successfully uploaded to GitHub Release!"
  elif [ $STATUS_CODE = 422 ]; then
    echo "ERROR: Asset ($FILENAME) already exist on this GitHub Release, aborting!"
    exit 1
  else
    echo "ERROR: Something went wrong (status code: $STATUS_CODE), aborting!"
    exit 1
  fi
}

delete_asset () {
  local ASSET_URL=$1

  echo ""
  if [ -z ${ASSET_URL+x} ]; then
    echo "Missing argument ASSET_URL, aborting!"
    exit 1
  fi

  echo "Deleting asset ($FILENAME) from GitHub Release..."

  local STATUS_CODE=$(
    curl -sL -o /dev/null -w '%{http_code}' \
      -X DELETE \
      --header "Accept: application/vnd.github.v3+json" \
      --header "Authorization: token $TOKEN" \
      $ASSET_URL
  )

  if [ $STATUS_CODE = 204 ]; then
    echo "SUCCESS: Asset ($FILENAME) successfully deleted from GitHub Release!"
  else
    echo "ERROR: Something went wrong (status code: $STATUS_CODE), aborting!"
    exit 1
  fi
}

echo "Fetching list of existing assets (if any) on GitHub Release..."

RESPONSE_PATH="response.json"
STATUS_CODE=$(
  curl -sL -o $RESPONSE_PATH -w '%{http_code}' \
    --header "Accept: application/vnd.github.v3+json" \
    --header "Authorization: token $TOKEN" \
    https://api.github.com/repos/$REPOSITORY/releases/$RELEASE_ID/assets
)

if [ $STATUS_CODE = 200 ]; then
  echo "SUCCESS: Fetched list of existing assets on GitHub Release!"
else
  echo "ERROR: Something went wrong (status code: $STATUS_CODE), aborting!"
  exit 1
fi

ASSET_URL=$(
  jq --raw-output ".[] | select(.name==\"$FILENAME\") | .url" $RESPONSE_PATH
)

# Cleanup
rm $RESPONSE_PATH

if [ -n "$ASSET_URL" ]; then
  echo "Asset with the filename $FILENAME already exist."
  delete_asset $ASSET_URL
else
  echo "No asset with the filename $FILENAME exist."
fi

upload_asset
