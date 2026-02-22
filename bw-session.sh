#!/usr/bin/env bash

err() {
  printf 'bw-session: %s\n' "$*" >&2
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "missing required command: $1"
    return 1
  }
}

SOURCED=0
SHOW_HINTS=1
VERSION="0.1.0"
if [[ -n "${BASH_SOURCE:-}" ]] && [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  SOURCED=1
elif [[ -n "${ZSH_VERSION:-}" ]] && [[ "${ZSH_EVAL_CONTEXT:-}" == *:file* ]]; then
  SOURCED=1
fi

if [[ "${SOURCED}" -eq 0 ]]; then
  set -euo pipefail
fi

run_bw() {
  if [[ "${SOURCED}" -eq 1 ]]; then
    command bw "$@"
    return $?
  fi
  exec bw "$@"
}

usage() {
  cat <<'USAGE'
Usage:
  bw-session [--bash|--zsh|--fish] [--refresh-session] # emit shell assignment
  source ~/.local/bin/bw-session [--refresh-session] # export in current bash/zsh shell
  bw-session [--refresh-session] <bw args...>        # run bw command with valid session
  bw-session --version                               # print version

Options:
  --refresh-session  Force a fresh BW_SESSION (invalidates previous session).
  --bash             Emit bash assignment syntax when no bw args are passed.
  --zsh              Emit zsh assignment syntax when no bw args are passed.
  --fish             Emit fish assignment syntax when no bw args are passed.
  --version          Show script version.
  -h, --help         Show this help.
USAGE
}

print_version() {
  printf 'bw-session %s\n' "${VERSION}"
}

detect_shell_name() {
  local pid="${PPID:-}" comm="" sh=""

  # Walk process ancestry and use the nearest parent shell.
  for _ in 1 2 3 4 5 6 7 8; do
    [[ -n "${pid}" ]] || break
    comm="$(ps -p "${pid}" -o comm= 2>/dev/null | awk '{print $1}')"
    comm="${comm##*/}"
    comm="${comm#-}"
    case "${comm}" in
      fish|zsh|bash)
        printf '%s' "${comm}"
        return 0
        ;;
      *)
        ;;
    esac
    pid="$(ps -p "${pid}" -o ppid= 2>/dev/null | tr -d '[:space:]')"
  done

  sh="${SHELL##*/}"
  sh="${sh#-}"
  printf '%s' "${sh:-bash}"
}

color_echo() {
  local color="$1"
  shift
  if [[ -t 2 ]]; then
    printf '\033[%sm%s\033[0m\n' "${color}" "$*" >&2
  else
    printf '%s\n' "$*" >&2
  fi
}

print_export_hints() {
  [[ "${SHOW_HINTS:-1}" -eq 1 ]] || return 0
  local current_shell="$1"
  local exported="${2:-0}"
  if [[ "${exported}" == "1" ]]; then
    color_echo "32" "bw-session: BW_SESSION exported for the current shell."
  else
    color_echo "33" "bw-session: session generated, but not exported in this shell process."
    if [[ "${current_shell}" == "fish" ]]; then
      color_echo "36" "bw-session: export in this fish shell with: eval (bw-session --fish)"
    else
      color_echo "36" "bw-session: export in this shell with: eval \"\$(bw-session)\""
    fi
  fi

  if [[ "${current_shell}" == "fish" ]]; then
    color_echo "36" "bw-session: for another fish shell, run there: eval (bw-session --fish)"
    color_echo "36" "bw-session: for bash/zsh shell, run there: eval \"\$(bw-session)\""
  else
    color_echo "36" "bw-session: for another bash/zsh shell, run there: eval \"\$(bw-session)\""
    color_echo "36" "bw-session: for fish shell, run there: eval (bw-session --fish)"
  fi
}

session_valid() {
  local s="$1"
  [[ -n "${s}" ]] || return 1
  bw --session "${s}" unlock --check --quiet >/dev/null 2>&1
}

print_assignment() {
  local shell_mode="$1"
  local s="$2"
  if [[ "${shell_mode}" == "fish" ]]; then
    printf 'set -gx BW_SESSION %q\n' "${s}"
  else
    printf 'export BW_SESSION=%q\n' "${s}"
  fi
}

set_current_shell_session() {
  local s="$1"
  local current_shell
  export BW_SESSION="${s}"
  current_shell="$(detect_shell_name)"
  print_export_hints "${current_shell}" 1
}

read_keychain() {
  local service="$1"
  local keychain_output rc errexit_was_on=0
  if [[ "${-}" == *e* ]]; then
    errexit_was_on=1
  fi
  set +e
  keychain_output="$(
    security find-generic-password -a "${USER}" -s "${service}" -w 2>&1
  )"
  rc=$?
  if [[ "${errexit_was_on}" -eq 1 ]]; then
    set -e
  fi

  if [[ "${rc}" -ne 0 ]]; then
    case "${keychain_output}" in
      *"could not be found in the keychain"*)
        err "Keychain item ${service} not found for current user"
        ;;
      *)
        err "unable to read Keychain item ${service}: ${keychain_output}"
        ;;
    esac
    return "${rc}"
  fi

  printf '%s' "${keychain_output}"
}

main() {
  local shell_mode="bash"
  local mode_forced=0
  local refresh_session=0
  local detected_shell
  local existing_session_valid=1
  local errexit_was_on=0
  local read_rc

  if [[ "${-}" == *e* ]]; then
    errexit_was_on=1
  fi

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --no-hints)
        SHOW_HINTS=0
        shift
        ;;
      --bash)
        shell_mode="bash"
        mode_forced=1
        shift
        ;;
      --zsh)
        shell_mode="zsh"
        mode_forced=1
        shift
        ;;
      --fish)
        shell_mode="fish"
        mode_forced=1
        shift
        ;;
      --refresh-session)
        refresh_session=1
        shift
        ;;
      --help|-h)
        usage
        return 0
        ;;
      --version)
        print_version
        return 0
        ;;
      *)
        break
        ;;
    esac
  done

  need_cmd bw
  need_cmd security
  need_cmd jq

  detected_shell="$(detect_shell_name)"

  if [[ "${mode_forced}" -eq 0 ]]; then
    case "${detected_shell}" in
      fish) shell_mode="fish" ;;
      bash) shell_mode="bash" ;;
      zsh) shell_mode="zsh" ;;
      *) shell_mode="bash" ;;
    esac
  fi

  case "${1:-}" in
    login|unlock|logout|config|update|--help|-h|help|status)
      run_bw "$@"
      return $?
      ;;
    *)
      ;;
  esac

  for arg in "$@"; do
    if [[ "${arg}" == "--session" ]]; then
      run_bw "$@"
      return $?
    fi
  done

  if [[ "${refresh_session}" -eq 0 ]]; then
    set +e
    session_valid "${BW_SESSION:-}"
    existing_session_valid=$?
    if [[ "${errexit_was_on}" -eq 1 ]]; then
      set -e
    fi
  fi

  if [[ "${refresh_session}" -eq 0 ]] && [[ "${existing_session_valid}" -eq 0 ]]; then
    if [[ $# -eq 0 ]]; then
      if [[ "${SOURCED}" -eq 1 ]]; then
        set_current_shell_session "${BW_SESSION}"
      else
        print_assignment "${shell_mode}" "${BW_SESSION}"
        print_export_hints "${detected_shell}" 0
      fi
      return 0
    fi

    run_bw "$@" --session "${BW_SESSION}"
    return $?
  fi

  local BW_CLIENTID BW_CLIENTSECRET BW_MASTER_PASSWORD status
  set +e
  BW_CLIENTID="$(read_keychain BW_CLIENTID)"
  read_rc=$?
  if [[ "${errexit_was_on}" -eq 1 ]]; then
    set -e
  fi
  if [[ "${read_rc}" -ne 0 ]]; then
    return "${read_rc}"
  fi

  set +e
  BW_CLIENTSECRET="$(read_keychain BW_CLIENTSECRET)"
  read_rc=$?
  if [[ "${errexit_was_on}" -eq 1 ]]; then
    set -e
  fi
  if [[ "${read_rc}" -ne 0 ]]; then
    return "${read_rc}"
  fi

  set +e
  BW_MASTER_PASSWORD="$(read_keychain BW_MASTER_PASSWORD)"
  read_rc=$?
  if [[ "${errexit_was_on}" -eq 1 ]]; then
    set -e
  fi
  if [[ "${read_rc}" -ne 0 ]]; then
    return "${read_rc}"
  fi

  if [[ -z "${BW_CLIENTID}" ]]; then
    err 'Keychain item BW_CLIENTID is empty'
    return 1
  fi
  if [[ -z "${BW_CLIENTSECRET}" ]]; then
    err 'Keychain item BW_CLIENTSECRET is empty'
    return 1
  fi
  if [[ -z "${BW_MASTER_PASSWORD}" ]]; then
    err 'Keychain item BW_MASTER_PASSWORD is empty'
    return 1
  fi

  status="$(bw status | jq -r '.status')"
  if [[ "${status}" == "unauthenticated" ]]; then
    BW_CLIENTID="${BW_CLIENTID}" BW_CLIENTSECRET="${BW_CLIENTSECRET}" bw login --apikey >/dev/null
  fi

  BW_SESSION="$(
    BW_MASTER_PASSWORD="${BW_MASTER_PASSWORD}" bw unlock --passwordenv BW_MASTER_PASSWORD --raw
  )"
  unset BW_MASTER_PASSWORD BW_CLIENTID BW_CLIENTSECRET

  if [[ $# -eq 0 ]]; then
    if [[ "${SOURCED}" -eq 1 ]]; then
      set_current_shell_session "${BW_SESSION}"
    else
      print_assignment "${shell_mode}" "${BW_SESSION}"
      print_export_hints "${detected_shell}" 0
    fi
    return 0
  fi

  run_bw "$@" --session "${BW_SESSION}"
  return $?
}

rc=0
if [[ "${SOURCED}" -eq 1 ]]; then
  sourced_errexit_was_on=0
  if [[ "${-}" == *e* ]]; then
    sourced_errexit_was_on=1
  fi
  set +e
  main "$@"
  rc=$?
  if [[ "${sourced_errexit_was_on}" -eq 1 ]]; then
    set -e
  fi
else
  main "$@"
  rc=$?
fi
if [[ "${SOURCED}" -eq 1 ]]; then
  return "${rc}"
fi
exit "${rc}"
