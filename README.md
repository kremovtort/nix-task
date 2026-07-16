# nix-task

[Go Task](https://taskfile.dev/)-backed task runners defined as Nix attribute sets.

`mkTasks` generates an immutable `Taskfile.yml` in the Nix store. The
`nix-task` command resolves the current `packages.<system>.tasks` output on each
run and passes it to Go Task. Nix provides configuration and pinned tools; Go
Task keeps its existing task graph, caching, watch, and status semantics.

## Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-task.url = "github:kremovtort/nix-task";
    nix-task.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, nix-task, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      tasks = nix-task.lib.mkTasks {
        inherit pkgs;
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
        packages = [ nix-task.packages.${system}.default ];
      };
    };
}
```

Enter the development shell once, then edit and run tasks without re-entering
it:

```console
$ nix develop
$ nix-task hello
$ nix-task hello # Uses an updated task definition, if it changed.
```

Run without entering the development shell:

```console
$ nix run github:kremovtort/nix-task -- hello
Hello, world!
```

The `taskfile` value follows the Taskfile v3 schema directly. Nix string
interpolation can put pinned package paths in commands, and those packages stay
in the generated Taskfile's closure. `nix-task` caches the resulting store path
under `$XDG_CACHE_HOME/nix-task` and invalidates it from Nix's archived flake
graph. If that graph is unchanged, subsequent calls skip flake evaluation and
reuse the GC-rooted Taskfile.

Tasks run from the directory where the runner is invoked. Relative task paths,
including `dir`, `dotenv`, `sources`, and `generates`, therefore behave like a
project-local Taskfile.

Relative `includes.*.taskfile` paths are the exception: Go Task resolves them
from the generated Taskfile in the Nix store. Use an absolute generated store
path for an included Taskfile, or compose the task attribute sets in Nix.
