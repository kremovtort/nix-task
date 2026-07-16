{ pkgs }:

pkgs.writeShellApplication {
  name = "nix-task";
  runtimeInputs = [ pkgs.go-task ];
  text = ''
    taskfile="''${NIX_TASK_FILE:-}"
    if [[ -z "$taskfile" ]]; then
      printf 'nix-task: NIX_TASK_FILE is not set; enter a dev shell configured with lib.mkTasks\n' >&2
      exit 1
    fi

    if [[ ! -r "$taskfile" ]]; then
      printf 'nix-task: cannot read Taskfile %s\n' "$taskfile" >&2
      exit 1
    fi

    exec task --taskfile "$taskfile" --dir "$PWD" "$@"
  '';
}
