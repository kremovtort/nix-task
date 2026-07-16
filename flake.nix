{
  description = "Go Task-backed task runners defined in Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkTasks = import ./nix-task.nix;
    in
    {
      lib = { inherit mkTasks; };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = import ./package.nix { inherit pkgs; };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          taskShell = mkTasks {
            inherit pkgs;
            taskfile = {
              version = "3";
              silent = true;
              tasks.show.cmds = [ ''test -f marker && read value && test "$value" = ok && printf 'passed\n' '' ];
            };
          };
          devShell = pkgs.mkShell { inputsFrom = [ taskShell ]; };
        in
        {
          default = pkgs.runCommand "nix-task-check" { nativeBuildInputs = devShell.nativeBuildInputs; } ''
            ${devShell.shellHook}

            mkdir project
            cd project
            touch marker
            output=$(printf 'ok\n' | nix-task show)
            [[ "$output" == passed ]]

            unset NIX_TASK_FILE
            if nix-task >stdout 2>stderr; then
              exit 1
            fi
            [[ "$(<stderr)" == *"NIX_TASK_FILE is not set"* ]]

            touch "$out"
          '';
        }
      );
    };
}
