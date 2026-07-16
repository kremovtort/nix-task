{ pkgs }:
args:
let
  taskfile = args // {
    version = "3";
  };
  generatedTaskfile = (pkgs.formats.yaml { }).generate "Taskfile.yml" taskfile;
  taskRunner = import ./package.nix { inherit pkgs; };
in
pkgs.mkShell {
  packages = [ taskRunner ];
  shellHook = ''
    export NIX_TASK_FILE=${generatedTaskfile}
  '';
}
