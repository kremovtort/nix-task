{
  pkgs,
  taskfile,
}:
(pkgs.formats.yaml { }).generate "Taskfile.yml" taskfile
