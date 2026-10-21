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
sbx run -d --name command-code-agent /path/to/this/kit "$PWD"
```

Replace `/path/to/this/kit` with this directory. `-d` keeps the sandbox running
after the command returns. Omit `-d` to attach an interactive shell instead.

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
folder by itself. Use the opener to connect and open the workspace in one step:

```sh
./open-vscode.sh
```

That runs:

```sh
code --remote "ssh-remote+command-code-agent.sbx" /home/agent/workspace
```

Pass another sandbox name or folder if needed:

```sh
./open-vscode.sh my-sandbox /home/agent/workspace
```

Manual alternative: **Remote-SSH: Connect to Host...** →
`command-code-agent.sbx`, then **File > Open Folder** →
`/home/agent/workspace` (linked to your project) or the host path from the
`WORKSPACE` column of `sbx ls`.

The first connection downloads the VS Code Server into the sandbox. The kit's
network allow list covers the download and the Marketplace.

## Command Code

The kit preinstalls `commandcode.commandcode-vscode` version `0.2.3` into
`~/.vscode-server/extensions`, so the extension is available in the remote
window without a separate install. If it does not appear after the first
connection, run **Developer: Reload Window** or install it once from the
Extensions view.

To pin another version, pass the kit argument when the sandbox is created:

```sh
sbx run -d --name command-code-agent /path/to/this/kit "$PWD" \
  --kit-arg commandcodeVersion=0.2.4
```

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

## Notes

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
