# packages

APT repository for JeffCurless' projects, served from GitHub Pages at
<https://jeffcurless.github.io/packages/>.

## Using the repository (all users)

Anyone can install these packages. Run the commands below **once on each
computer** to add the repository; you don't need to repeat them.

```bash
sudo curl -fsSL https://jeffcurless.github.io/packages/public.gpg \
  -o /usr/share/keyrings/jeffcurless-packages.gpg
echo "deb [signed-by=/usr/share/keyrings/jeffcurless-packages.gpg] https://jeffcurless.github.io/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/jeffcurless-packages.list
sudo apt update
```

Then `sudo apt install <package>`; later updates arrive through
`sudo apt update && sudo apt upgrade`.

## Publishing (maintainer only)

Only the maintainer publishes packages; users don't need this section.
Publishing needs the private signing key, which only the maintainer has.

1. Bump the package version. apt only upgrades when the version increases.
2. Build and test the `.deb`.
3. Copy it into `incoming/`.
4. Run `./publish.sh`. It adds the package, signs the index, commits and pushes.

Other commands:

- `./publish.sh list` lists packages and versions in the repository.
- `./publish.sh remove <pkg>` removes a package.
- `./publish.sh replace` publishes what is in `incoming/` even when its version
  is not newer, removing the existing version first. Use it to fix a wrong
  version number. Computers that already installed a higher version need
  `sudo apt install --allow-downgrades <pkg>=<version>`.
- `./publish.sh prune` throws away the git history (and with it every old
  `.deb`) and force-pushes a single commit with the current files. It asks you
  to type `prune` first.

Publishing a newer version automatically deletes the older one from the
repository, so only the current version of each package is offered.

Signing key ID: `BEAB286B05F216A2` (the private key lives only on the
maintainer's machine; the public key is `public.gpg`).
