{
  pkgs,
  taskfile,
  name ? "task",
  taskPackage ? pkgs.go-task,
}:
let
  generatedTaskfile = (pkgs.formats.yaml { }).generate "Taskfile.yml" taskfile;
in
pkgs.writeShellScriptBin name ''
  exec ${taskPackage}/bin/task --taskfile ${generatedTaskfile} --dir "$PWD" "$@"
''
