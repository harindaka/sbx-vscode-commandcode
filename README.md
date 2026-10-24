# Command Code agent sandbox kit

An [sbx](https://docs.docker.com/ai/sandboxes/) sandbox kit for running VS Code
Desktop's **Remote - SSH** against a microVM. The editor UI stays on your host;
the workspace, terminals, and the Command Code extension run inside the
sandbox.

No SSH server runs inside the sandbox: `sbx` terminates SSH at its daemon and
proxies the connection to the VM.

## Prerequisites

- Docker Sandboxes (`sbx`) installed and signed in: `sbx login`
- VS Code Desktop with the **Remote - SSH** extension
  (`ms-vscode-remote.remote-ssh`)
- One-time host SSH setup:

  ```sh
  sbx setup ssh
  ```

## Create and start the sandbox

From the project you want to work on:

```sh
sbx run -d --name command-code-agent \
  ghcr.io/harindaka/sbx-vscode-commandcode:0.1.2 "$PWD"
```

`-d` keeps the sandbox running after the command returns. Omit `-d` to attach an
interactive shell instead. To run from a local checkout of this kit instead of
the published artifact, pass the directory in place of the registry reference:

```sh
sbx run -d --name command-code-agent /path/to/this/kit "$PWD"
```

The workspace is mounted at the same absolute path inside the sandbox. For
example, if you ran the command from `/home/you/src/my-project`, the sandbox
sees it at `/home/you/src/my-project`.

The kit also points `/home/agent/workspace` — the base image's default
workdir — at that path, so SSH and VS Code open the project automatically
instead of an empty directory.

Verify the connection:

```sh
ssh command-code-agent.sbx
```

## Connect VS Code

`Remote - SSH: Connect to Host...` opens an empty window; it does not open a
folder by itself. `vsccc.sh up` ensures the sandbox exists and is running, then
connects and opens the workspace in one step. It is idempotent, so running it
again just reconnects:

```sh
./vsccc.sh up
```

That runs:

```sh
code --remote "ssh-remote+command-code-agent" /home/agent/workspace
```

Pass a sandbox name to create or reconnect to a different one:

```sh
./vsccc.sh up my-sandbox
```

Manual alternative: **Remote-SSH: Connect to Host...** →
`command-code-agent.sbx`, then **File > Open Folder** →
`/home/agent/workspace` (linked to your project) or the host path from the
`WORKSPACE` column of `sbx ls`.

The first connection downloads the VS Code Server into the sandbox. The kit's
network allow list covers the download and the Marketplace.

## Command Code

The kit preinstalls `commandcode.commandcode-vscode` into
`~/.vscode-server/extensions`, so the extension is available in the remote
window without a separate install. The checked-in spec resolves `latest` when
each sandbox is created; `publish.sh` replaces that with the newest Marketplace
version at publish time, so a published artifact is reproducible.

Pass the kit argument to track the newest version in a published sandbox, or to
pin a specific one:

```sh
sbx run -d --name command-code-agent \
  ghcr.io/harindaka/sbx-vscode-commandcode:0.1.2 "$PWD" \
  --kit-arg commandcodeVersion=latest
```

If it does not appear after the first connection, run **Developer: Reload
Window** or install it once from the Extensions view.

### Sign-in callback

Command Code runs a temporary loopback callback server on ports **5959-5968**
inside the sandbox. Remote - SSH normally forwards those ports to your host
automatically.

If the browser sign-in does not complete, open VS Code's **Ports** panel for the
remote window and forward `5959` (and, if needed, the rest of the range), or
reconnect with local forwards:

```sh
ssh -L 5959:127.0.0.1:5959 -L 5960:127.0.0.1:5960 \
    -L 5961:127.0.0.1:5961 -L 5962:127.0.0.1:5962 \
    -L 5963:127.0.0.1:5963 -L 5964:127.0.0.1:5964 \
    -L 5965:127.0.0.1:5965 -L 5966:127.0.0.1:5966 \
    -L 5967:127.0.0.1:5967 -L 5968:127.0.0.1:5968 \
    command-code-agent.sbx
```

Authentication persists inside the sandbox across stops and restarts.

## Lifecycle

```sh
sbx stop command-code-agent   # pause, keep installed tools and sign-in state
sbx run -d --name command-code-agent   # start it again
sbx rm command-code-agent     # delete the sandbox and everything in it
```

## Publishing the kit

```sh
./publish.sh patch     # or minor, major, or an explicit X.Y.Z
```

`publish.sh` validates the kit, resolves the newest Command Code extension from
the Marketplace, stages only `spec.yaml`, `README.md`, and `LICENSE` into
`dist/` (`sbx kit push` archives every file in the directory, including `.git/`,
so it must never run from the repo root), pins the extension version in the
staged spec, bumps `VERSION`, updates the reference in `vsccc.sh` and this
README, commits, pushes the kit, then tags and pushes `vX.Y.Z`.

It needs a clean working tree and registry credentials. If it cannot find GHCR
credentials in the Docker config, it runs `docker login ghcr.io` for you; you can
also log in ahead of time with `docker login ghcr.io`, `sbx login`, or
`sbx secret set --registry ghcr.io`. Set `KIT_IMAGE` to push somewhere else and
`KIT_SIGN=1` for keyless Sigstore signing. Make the GHCR package public in its
settings if others should pull it without credentials. Every push also attaches
SLSA provenance.

Manual equivalent:

```sh
sbx kit validate .
rm -rf dist && mkdir -p dist
cp spec.yaml README.md LICENSE dist/
sbx kit push dist ghcr.io/harindaka/sbx-vscode-commandcode:0.1.2
```

`vsccc.sh` uses that reference by default. Override it with `VSCCC_KIT` to try a
local or differently tagged kit:

```sh
VSCCC_KIT="$PWD" ./vsccc.sh up my-sandbox
```

## Notes

- The VS Code Server is not baked into the kit. Remote - SSH downloads the
  version matching your desktop client on the first connection, so it is always
  current; the kit's allow list covers the download hosts.
- The base image is `docker.io/docker/sandbox-templates:shell`; it has no
  Docker daemon inside the sandbox. Switch to
  `docker.io/docker/sandbox-templates:shell-docker` if the agent needs an
  isolated Docker Engine.
- This kit installs the VS Code extension only. If you also want the `cmd` CLI
  in the integrated terminal, add this to `setup.install`:

  ```yaml
  - command: npm install -g command-code
    user: "0"
    description: Install the Command Code CLI
  ```
