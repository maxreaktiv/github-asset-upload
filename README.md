### Upload asset to GitHub Release

#### Get release-id:

```bash
curl -s -H "Authorization: token <github-token>" https://api.github.com/repos/<user>/<some-repo>/releases | jq '.[0].id'
```

#### Upload file:

```bash
./github-asset-upload.sh "<user>/<some-repo>" "<github-token>" "<release-id>" "path/to/file"
```
