# create-apt-repo

Create an APT repo using [reprepro](https://manpages.debian.org/bookworm/reprepro/reprepro.1.en.html).

## Usage

```yaml
      - uses: skaylink-stefan-heitmueller/create-apt-repo@v24.1.1
        id: create-apt-repo
        with:
          repo-name: my-fancy-tool
          signing-key: ${{ secrets.SIGNING_KEY }}
          codename: jammy
          architectures: amd64 arm64
```

## Parameters

See `inputs` in `action.yml`.
