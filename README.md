# nix-task

A flake-only [Go Task](https://taskfile.dev/)-backed task runner with tasks defined as Nix attribute sets.

`mkTasks` generates an immutable `Taskfile.yml` in the Nix store and returns a `pkgs.mkShell` derivation for `inputsFrom`. Nix provides configuration and pinned tools; Go Task keeps its existing task graph, caching, watch, and status semantics. The `task` command does not evaluate the project flake at runtime.

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
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [
          (nix-task.lib.${system}.mkTasks {
            tasks.hello = {
              desc = "Say hello";
              cmds = [ "${pkgs.hello}/bin/hello" ];
            };
          })
        ];
      };
    };
}
```

Enter the development shell and run tasks:

```console
$ nix develop
$ task hello
```

The arguments follow the Taskfile v3 schema directly; `version = "3"` is added automatically. Nix string interpolation can put pinned package paths in commands, and those packages stay in the generated Taskfile's closure. Changes to the task definition take effect after re-entering or reloading the development shell.

Tasks run from the directory where the runner is invoked. Relative task paths, including `dir`, `dotenv`, `sources`, and `generates`, therefore behave like a project-local Taskfile.

Relative `includes.*.taskfile` paths are the exception: Go Task resolves them from the generated Taskfile in the Nix store. Use an absolute generated store path for an included Taskfile, or compose the task attribute sets in Nix.
