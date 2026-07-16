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
      mkTasksFor = system: import ./nix-task.nix { pkgs = nixpkgs.legacyPackages.${system}; };
    in
    {
      lib = forAllSystems (system: {
        mkTasks = mkTasksFor system;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          taskShell = (mkTasksFor system) {
            silent = true;
            tasks.show.cmds = [ ''test -f marker && read value && test "$value" = ok && printf 'passed\n' '' ];
          };
          devShell = pkgs.mkShell { inputsFrom = [ taskShell ]; };
        in
        {
          default = pkgs.runCommand "nix-task-check" { nativeBuildInputs = devShell.nativeBuildInputs; } ''
            ${devShell.shellHook}

            mkdir project
            cd project
            touch marker
            output=$(printf 'ok\n' | task show)
            [[ "$output" == passed ]]

            unset NIX_TASK_FILE
            if task >stdout 2>stderr; then
              exit 1
            fi
            [[ "$(<stderr)" == *"NIX_TASK_FILE is not set"* ]]

            touch "$out"
          '';
        }
      );
    };
}
