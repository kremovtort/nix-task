{ pkgs }:

pkgs.writeShellApplication {
  name = "nix-task";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.go-task
    pkgs.jq
  ];
  text = ''
    working_dir=$PWD
    root=$(pwd -P)

    if ! command -v nix >/dev/null 2>&1; then
      printf 'nix-task: nix not found in PATH\n' >&2
      exit 127
    fi

    while [[ ! -f "$root/flake.nix" ]]; do
      if [[ "$root" == / ]]; then
        printf 'nix-task: no flake.nix found from %s\n' "$working_dir" >&2
        exit 1
      fi
      root="''${root%/*}"
      [[ -n "$root" ]] || root=/
    done

    archive_json=$(nix --option warn-dirty false flake archive --json "$root")
    archive_path=$(jq -er .path <<< "$archive_json")
    archive_key=$(printf '%s' "$archive_json" | sha256sum)
    archive_key="''${archive_key%% *}"
    project_key=$(printf '%s' "$root" | sha256sum)
    project_key="''${project_key%% *}"
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-task"
    cache_file="$cache_dir/$project_key"
    taskfile_link="$cache_dir/$project_key-taskfile"

    cached_key=
    taskfile=
    if [[ -r "$cache_file" ]]; then
      read -r cached_key taskfile < "$cache_file" || true
    fi

    rooted_taskfile=
    if [[ -L "$taskfile_link" ]]; then
      rooted_taskfile=$(readlink "$taskfile_link")
    fi

    if [[ "$cached_key" != "$archive_key" || ! -e "$taskfile" || "$rooted_taskfile" != "$taskfile" ]]; then
      mkdir -p "$cache_dir"
      taskfile=$(nix build --out-link "$taskfile_link" --print-out-paths "$archive_path#tasks")
      temporary_cache="$cache_file.$$"
      printf '%s %s\n' "$archive_key" "$taskfile" > "$temporary_cache"
      mv -f "$temporary_cache" "$cache_file"
    fi

    exec task --taskfile "$taskfile" --dir "$working_dir" "$@"
  '';
}
