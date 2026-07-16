{
  pkgs,
  taskfile,
}:
let
  generatedTaskfile = (pkgs.formats.yaml { }).generate "Taskfile.yml" taskfile;
  nixTask = import ./package.nix { inherit pkgs; };
in
pkgs.mkShell {
  packages = [ nixTask ];
  shellHook = ''
    export NIX_TASK_FILE=${generatedTaskfile}
  '';
}
