# nix-task

[Go Task](https://taskfile.dev/)-backed task runners defined as Nix attribute sets.

`mkTasks` generates an immutable `Taskfile.yml` in the Nix store and wraps
Go Task with that file. Nix provides configuration and pinned tools; Go Task
keeps its existing task graph, caching, watch, and status semantics.

## Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-task.url = "github:kremovtort/nix-task";
  };

  outputs =
    { nixpkgs, nix-task, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      tasks = nix-task.lib.mkTasks {
        inherit pkgs;
        name = "task";
        taskfile = {
          version = "3";
          tasks.hello = {
            desc = "Say hello";
            cmds = [ "${pkgs.hello}/bin/hello" ];
          };
        };
      };
    in
    {
      packages.${system}.tasks = tasks;
      devShells.${system}.default = pkgs.mkShell {
        packages = [ tasks ];
      };
    };
}
```

Run without entering the development shell:

```console
$ nix run .#tasks -- hello
Hello, world!
```

The `taskfile` value follows the Taskfile v3 schema directly. Nix string
interpolation can put pinned package paths in commands, and those packages stay
in the runner's closure.

Tasks run from the directory where the runner is invoked. Relative task paths,
including `dir`, `dotenv`, `sources`, and `generates`, therefore behave like a
project-local Taskfile.

Relative `includes.*.taskfile` paths are the exception: Go Task resolves them
from the generated Taskfile in the Nix store. Use an absolute generated store
path for an included Taskfile, or compose the task attribute sets in Nix.
