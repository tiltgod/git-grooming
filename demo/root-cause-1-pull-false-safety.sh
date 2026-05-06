#!/usr/bin/env bash
# Root cause 1 — `git pull` gives false safety.
# Show: pull makes you "up to date" for one moment, then divergence resumes.
# Run: bash root-cause-1-pull-false-safety.sh
set -e

DEMO=/tmp/grooming-demo-pull
rm -rf "$DEMO" && mkdir -p "$DEMO" && cd "$DEMO"

mkdir remote.git && git -C remote.git init -q --bare -b main
mkdir devA devB

setup_clone() {
  local d=$1
  git -C "$d" init -q -b main
  git -C "$d" config user.email "$d@local"
  git -C "$d" config user.name "$d"
  git -C "$d" remote add origin "$DEMO/remote.git"
}
setup_clone devA
setup_clone devB

echo "init" > devA/file.txt
git -C devA add . && git -C devA commit -q -m init
git -C devA push -q -u origin main
git -C devB pull -q origin main
git -C devB checkout -q -b feature/B

show_divergence() {
  git -C devB fetch -q origin
  local ahead behind
  ahead=$(git -C devB rev-list --count origin/main..HEAD)
  behind=$(git -C devB rev-list --count HEAD..origin/main)
  echo "  feature/B vs origin/main: ahead=$ahead behind=$behind"
}

echo "=== T0: Dev B branches off main ==="
show_divergence

echo
echo "=== T1: Dev A pushes 3 commits to main ==="
for i in 1 2 3; do
  echo "A change $i" >> devA/file.txt
  git -C devA commit -qam "A: change $i"
done
git -C devA push -q origin main
show_divergence
echo "  → Dev B is behind 3, doesn't know yet"

echo
echo "=== T2: Dev B runs 'git pull origin main' — feels safe ==="
git -C devB pull -q --no-rebase origin main >/dev/null 2>&1 || true
show_divergence
echo "  → behind=0. 'I'm up to date.'"

echo
echo "=== T3: rest of the day passes. Dev A keeps merging. ==="
for i in 4 5; do
  echo "A change $i" >> devA/file.txt
  git -C devA commit -qam "A: change $i"
done
git -C devA push -q origin main

echo "Dev B keeps coding on feature/B (didn't re-pull):"
echo "B work" >> devB/file.txt
git -C devB commit -qam "B: feature work"
show_divergence
echo "  → behind again. 'up to date' was true for ~5 minutes."

echo
echo "Lesson: pull is a snapshot. Divergence resumes the next commit on either side."
echo "Demo dir: $DEMO"
