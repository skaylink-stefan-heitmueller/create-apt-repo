# create-apt-repo

Create an APT repo using [reprepro](https://manpages.debian.org/bookworm/reprepro/reprepro.1.en.html).

## Usage

```yaml
permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    outputs:
      artifact_id: ${{ steps.upload-artifact.outputs.artifact-id }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Setup Pages
        uses: actions/configure-pages@v4
      - name: Create packages
        run: |
          ...
          do something funny to create your packages using e.g. fpm, nfpm, ....
          ...
      - uses: skaylink-stefan-heitmueller/create-apt-repo@v24.1.1
        id: create-apt-repo
        with:
          repo-name: my-fancy-tool
          signing-key: ${{ secrets.SIGNING_KEY }}
          codename: jammy
          architectures: amd64 arm64
      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          name: github-pages
          path: ${{ steps.create-apt-repo.outputs.repodir }}
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

## Parameters

See `inputs` in `action.yml`.
