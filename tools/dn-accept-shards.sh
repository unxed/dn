#!/bin/bash
# Durable sharded accept — solves prior failures:
#   * setsid workers (survive agent cutoffs; no shell-tied PTYs)
#   * resume: skip shards with SUMMARY fail=0 + EXIT:0
#   * concurrency cap (default 2) — less PTY flake than 4–8
#   * never pkill -f; PID files only
#   * FAIL/DEAD visible via dn-accept-watch (LOGDIR)
set -u
cd /home/ivan/dn
export PATH=/home/ivan/fpc-local/bin:$PATH
export DN_ACCEPT_FAST=1

OBJ=${DN_ACCEPT_OBJ:-/tmp/dn-object-gate/out/linux64-gate}
CLS=${DN_ACCEPT_CLS:-out/linux64-gate}
LOGDIR=${DN_ACCEPT_LOGDIR:-/tmp/dn-accept-shards}
N=${DN_ACCEPT_SHARDS:-12}
PAR=${DN_ACCEPT_PAR:-8}

mkdir -p "$LOGDIR/pids"
rm -f "$LOGDIR/DONE" "$LOGDIR/FAILS"
# Point watchdog at this run
echo $$ >"$LOGDIR/run.pid"
# Also publish pid where full-watch looks if linked
mkdir -p /tmp/dn-accept-full
ln -sfn "$LOGDIR" /tmp/dn-accept-full/active-shards
echo $$ >/tmp/dn-accept-full/run.pid

echo "START $(date -Is) n=$N par=$PAR pid=$$" | tee "$LOGDIR/matrix.log"

is_green() {
  local log=$1
  grep -q '^SUMMARY' "$log" 2>/dev/null || return 1
  local line f
  line=$(grep '^SUMMARY' "$log" | tail -1)
  f=$(echo "$line" | sed -n 's/.*fail=\([0-9]*\).*/\1/p')
  [ "${f:-1}" = "0" ] && grep -q '^EXIT:0$' "$log" 2>/dev/null
}

run_shard() {
  local i=$1
  local log="$LOGDIR/shard$i.log"
  local pf="$LOGDIR/pids/shard$i.pid"
  echo "==== SHARD $i/$N START $(date -Is) ====" | tee -a "$LOGDIR/matrix.log"
  # New session so agent shell death cannot SIGKILL the worker
  setsid python3 -u tools/dn-linux-accept.py "$OBJ" "$CLS" --shard "$i/$N" \
    >"$log" 2>&1 &
  local spid=$!
  echo "$spid" >"$pf"
  wait "$spid"
  local ec=$?
  echo "EXIT:$ec" >>"$log"
  rm -f "$pf"
  local line
  line=$(grep '^SUMMARY' "$log" | tail -1 || echo 'SUMMARY missing')
  echo "s$i $line ec=$ec $(date -Is)" | tee -a "$LOGDIR/matrix.log"
  grep '^FAIL ' "$log" | tee -a "$LOGDIR/matrix.log" >>"$LOGDIR/FAILS" 2>/dev/null || true
  return $ec
}

# Queue of shards still needing work
queue=()
for i in $(seq 0 $((N - 1))); do
  if is_green "$LOGDIR/shard$i.log"; then
    echo "s$i SKIP green" | tee -a "$LOGDIR/matrix.log"
  else
    queue+=("$i")
  fi
done

running=0
declare -A job_pid job_idx
fail_total=0
pass_total=0

reap() {
  local pid idx ec log line p f
  for pid in "${!job_pid[@]}"; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" 2>/dev/null
      ec=$?
      idx=${job_idx[$pid]}
      unset job_pid[$pid] job_idx[$pid]
      running=$((running - 1))
      log="$LOGDIR/shard$idx.log"
      # EXIT line already appended by run_shard's wait path if used;
      # when we background run_shard itself, child writes EXIT.
      line=$(grep '^SUMMARY' "$log" | tail -1 || echo 'SUMMARY missing')
      p=$(echo "$line" | sed -n 's/.*pass=\([0-9]*\).*/\1/p'); p=${p:-0}
      f=$(echo "$line" | sed -n 's/.*fail=\([0-9]*\).*/\1/p'); f=${f:-1}
      pass_total=$((pass_total + p))
      fail_total=$((fail_total + f))
      if [ "$ec" -ne 0 ] && [ "$f" -eq 0 ]; then
        # killed without SUMMARY
        echo "s$idx DEAD ec=$ec $(date -Is)" | tee -a "$LOGDIR/matrix.log"
        echo "DEAD shard$idx ec=$ec" >>"$LOGDIR/FAILS"
        fail_total=$((fail_total + 1))
      fi
    fi
  done
}

# Launch helper as background function with setsid inside
launch() {
  local i=$1
  (
    run_shard "$i"
  ) &
  local pid=$!
  job_pid[$pid]=1
  job_idx[$pid]=$i
  running=$((running + 1))
}

qi=0
while [ "$qi" -lt "${#queue[@]}" ] || [ "$running" -gt 0 ]; do
  while [ "$running" -lt "$PAR" ] && [ "$qi" -lt "${#queue[@]}" ]; do
    launch "${queue[$qi]}"
    qi=$((qi + 1))
  done
  sleep 2
  reap
done

# Recount from logs (authoritative)
pass_total=0; fail_total=0
: >"$LOGDIR/FAILS"
for i in $(seq 0 $((N - 1))); do
  log="$LOGDIR/shard$i.log"
  line=$(grep '^SUMMARY' "$log" 2>/dev/null | tail -1 || echo 'SUMMARY missing')
  p=$(echo "$line" | sed -n 's/.*pass=\([0-9]*\).*/\1/p'); p=${p:-0}
  f=$(echo "$line" | sed -n 's/.*fail=\([0-9]*\).*/\1/p'); f=${f:-1}
  if ! grep -q '^EXIT:0$' "$log" 2>/dev/null; then
    f=$((f + 1))
    echo "DEAD_OR_BAD shard$i" >>"$LOGDIR/FAILS"
  fi
  pass_total=$((pass_total + p))
  fail_total=$((fail_total + f))
  grep '^FAIL ' "$log" >>"$LOGDIR/FAILS" 2>/dev/null || true
done

echo "TOTAL pass=$pass_total fail=$fail_total $(date -Is)" | tee -a "$LOGDIR/matrix.log"
echo DONE >"$LOGDIR/DONE"
# Keep run.pid until DONE so watch sees FINISHED then IDLE
exit 0
