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
          nixTask = import ./package.nix { inherit pkgs; };
          taskfileV1 = mkTasks {
            inherit pkgs;
            taskfile = {
              version = "3";
              tasks.show.cmds = [ ''test -f marker && read value && test "$value" = ok && printf 'v1\n' '' ];
            };
          };
          taskfileV2 = mkTasks {
            inherit pkgs;
            taskfile = {
              version = "3";
              tasks.show.cmds = [ ''test -f marker && read value && test "$value" = ok && printf 'v2\n' '' ];
            };
          };
          fakeNix = pkgs.writeShellScriptBin "nix" ''
            case "$1" in
              --option)
                printf '{"path":"/nix/store/source-%s"}\n' "$NIX_TASK_TEST_VERSION"
                ;;
              build)
                counter="$NIX_TASK_TEST_COUNTER-$NIX_TASK_TEST_VERSION"
                if [[ -e "$counter" ]]; then
                  printf 'unexpected rebuild for %s\n' "$NIX_TASK_TEST_VERSION" >&2
                  exit 1
                fi
                : > "$counter"
                case "$NIX_TASK_TEST_VERSION" in
                  v1) result=${taskfileV1} ;;
                  v2) result=${taskfileV2} ;;
                  *) exit 1 ;;
                esac
                while [[ "$1" != --out-link ]]; do shift; done
                ${pkgs.coreutils}/bin/ln -sfn "$result" "$2"
                printf '%s\n' "$result"
                ;;
              *) exit 1 ;;
            esac
          '';
        in
        {
          default = pkgs.runCommand "nix-task-check" { nativeBuildInputs = [ fakeNix ]; } ''
            mkdir project
            cd project
            touch flake.nix marker
            export XDG_CACHE_HOME="$PWD/cache"
            export NIX_TASK_TEST_COUNTER="$PWD/build"

            export NIX_TASK_TEST_VERSION=v1
            output=$(printf 'ok\n' | ${nixTask}/bin/nix-task show)
            [[ "$output" == *v1* ]]
            output=$(printf 'ok\n' | ${nixTask}/bin/nix-task show)
            [[ "$output" == *v1* ]]

            export NIX_TASK_TEST_VERSION=v2
            output=$(printf 'ok\n' | ${nixTask}/bin/nix-task show)
            [[ "$output" == *v2* ]]
            cd ..

            mkdir no-flake
            cd no-flake
            if ${nixTask}/bin/nix-task >stdout 2>stderr; then
              exit 1
            fi
            [[ "$(<stderr)" == *"no flake.nix found"* ]]

            touch "$out"
          '';
        }
      );
    };
}
