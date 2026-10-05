#!/bin/bash
# Permanent accept watchdog: FAILs as they appear + process death.
# Watches full run (/tmp/dn-accept-full) and/or shards (/tmp/dn-accept-shards).
# Managed by systemd --user dn-accept-watch.service (Restart=always).
set -u
FULL=/tmp/dn-accept-full
SHARDS=/tmp/dn-accept-shards
mkdir -p "$FULL" "$SHARDS"
EVENTS="$FULL/watch.events"
STATUS="$FULL/watch.status"
touch "$EVENTS"
echo "WATCH_START $(date -Is) pid=$$" | tee -a "$EVENTS" >"$STATUS"

seen_fails=0
last_scen=0
was_running=0
seen_fail_text=""

emit_new_fails() {
  local file=$1
  [ -f "$file" ] || return 0
  local lines
  lines=$(grep '^FAIL ' "$file" 2>/dev/null || true)
  [ -z "$lines" ] && return 0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$seen_fail_text" in
      *"|$line|"*) ;;
      *)
        seen_fail_text="${seen_fail_text}|$line|"
        echo "$(date -Is) $line" | tee -a "$EVENTS"
        seen_fails=$((seen_fails + 1))
        ;;
    esac
  done <<<"$lines"
}

while true; do
  pid=$(cat "$FULL/run.pid" 2>/dev/null || echo "")
  # Prefer shards orchestrator pid if present and alive
  spid=$(cat "$SHARDS/run.pid" 2>/dev/null || echo "")
  if [ -n "$spid" ] && kill -0 "$spid" 2>/dev/null; then
    pid=$spid
  fi

  alive=0
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    alive=1
  fi

  # Collect FAILs from whichever logs exist
  emit_new_fails "$FULL/accept.out"
  emit_new_fails "$SHARDS/FAILS"
  for f in "$SHARDS"/shard*.log; do
    [ -f "$f" ] || continue
    emit_new_fails "$f"
  done
  # DEAD markers from orchestrator
  if [ -f "$SHARDS/FAILS" ]; then
    while IFS= read -r line; do
      case "$line" in
        DEAD*|DEAD_OR_BAD*)
          case "$seen_fail_text" in
            *"|$line|"*) ;;
            *)
              seen_fail_text="${seen_fail_text}|$line|"
              echo "$(date -Is) $line" | tee -a "$EVENTS"
              ;;
          esac
          ;;
      esac
    done <"$SHARDS/FAILS"
  fi

  if [ "$alive" -eq 1 ]; then
    was_running=1
    mode=full
    out="$FULL/accept.out"
    if [ -n "$spid" ] && [ "$pid" = "$spid" ]; then
      mode=shards
      out="$SHARDS/matrix.log"
    fi
    if [ -f "$out" ]; then
      if [ "$mode" = shards ]; then
        cur=$(grep -c 'SHARD .* START\|s[0-9]* SUMMARY\|s[0-9]* SKIP' "$SHARDS/matrix.log" 2>/dev/null || echo 0)
        last=$(tail -1 "$SHARDS/matrix.log" 2>/dev/null || echo '')
        # live shard workers
        workers=$(ls "$SHARDS/pids"/shard*.pid 2>/dev/null | wc -l)
        # strip FAIL from status last= to avoid notify spam on rewritten STATUS
        last_safe=$(echo "$last" | sed "s/FAIL /fail:/g")
        echo "PROGRESS $(date -Is) mode=shards workers=$workers fails=$seen_fails last=$last_safe" >"$STATUS"
      else
        cur=$(grep -c '^SCENARIO ' "$FULL/accept.out" 2>/dev/null || echo 0)
        last=$(grep '^SCENARIO ' "$FULL/accept.out" 2>/dev/null | tail -1)
        echo "PROGRESS $(date -Is) mode=full scenarios=$cur fails=$seen_fails last=$last" >"$STATUS"
      fi
    else
      echo "RUNNING $(date -Is) pid=$pid fails=$seen_fails" >"$STATUS"
    fi
  else
    done_f=""
    [ -f "$FULL/DONE" ] && done_f=$FULL/DONE
    [ -f "$SHARDS/DONE" ] && done_f=$SHARDS/DONE
    if [ -n "$done_f" ] && [ "$was_running" -eq 1 ]; then
      echo "FINISHED $(date -Is) via $done_f" | tee -a "$EVENTS" >"$STATUS"
      [ -f "$SHARDS/matrix.log" ] && grep '^TOTAL' "$SHARDS/matrix.log" | tee -a "$EVENTS" || true
      [ -f "$FULL/accept.out" ] && grep '^SUMMARY' "$FULL/accept.out" | tee -a "$EVENTS" || true
      was_running=0
      seen_fails=0
      seen_fail_text=""
    elif [ "$was_running" -eq 1 ]; then
      echo "DEAD $(date -Is) pid=$pid" | tee -a "$EVENTS" >"$STATUS"
      was_running=0
    else
      echo "IDLE $(date -Is) fails_seen=$seen_fails" >"$STATUS"
    fi
  fi
  sleep 5
done
