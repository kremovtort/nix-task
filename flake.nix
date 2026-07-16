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

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          runner = mkTasks {
            inherit pkgs;
            name = "nix-task-check";
            taskfile = {
              version = "3";
              tasks.check.cmds = [ ''test -f marker && read value && test "$value" = ok'' ];
            };
          };
        in
        {
          default = pkgs.runCommand "nix-task-check" { nativeBuildInputs = [ runner ]; } ''
            mkdir work
            cd work
            touch marker
            printf 'ok\n' | nix-task-check check
            touch "$out"
          '';
        }
      );
    };
}
