# asdf-nub

[asdf](https://asdf-vm.com) / [mise](https://mise.jdx.dev) plugin for [nub](https://github.com/nubjs/nub) — the Rust CLI that augments your installed Node.

Installs `nub` (and its `nubx` and `nubr` aliases) from the official GitHub releases, with SHA-256 verification of every download.

## Install

Requires `bash`, `curl`, `git`, and `tar`.

### asdf

```sh
asdf plugin add nub https://github.com/nubjs/asdf-nub.git
asdf install nub latest
asdf set nub latest      # or: asdf global nub <version>
```

### mise

mise already ships nub in its registry, so no plugin is needed — `mise use nub@latest` installs the GitHub release tarball directly (nub 0.9.5 and later; older versions come from the npm package) with `nub`, `nubx` and `nubr` on `PATH`.

This plugin is for asdf. A mise user only needs it on a mise release older than the registry switch; install it explicitly first:

```sh
mise plugin install nub https://github.com/nubjs/asdf-nub.git
mise use nub@latest
```

## Usage

```sh
asdf list-all nub          # every installable version
asdf install nub 0.4.11    # a specific version
asdf install nub latest    # the latest stable release

nub --version
nubx --version
nubr --version
```

Pin a version per project with `.tool-versions`:

```
nub 0.4.11
```

## Platforms

Prebuilt releases exist for macOS (arm64, x64) and Linux (arm64, x64), including musl (Alpine). The plugin selects the right asset automatically and prefers the native arm64 build when a macOS shell is running under Rosetta 2. Windows is not supported (asdf is POSIX-only).

## Rate limits

`list-all` reads tags over `git` and needs no token. `latest-stable` calls the GitHub API; set `GITHUB_API_TOKEN` or `GITHUB_TOKEN` to avoid the unauthenticated rate limit on shared-IP CI runners.

## License

[MIT](LICENSE)
