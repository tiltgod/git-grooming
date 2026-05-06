#!/usr/bin/env bash
# Scenario B — good path: daily rebase catches conflict tiny + early.
# Run: bash scenario-b-good-path.sh
set -e

DEMO=/tmp/grooming-demo-b
rm -rf "$DEMO" && mkdir -p "$DEMO" && cd "$DEMO"

# Bare "remote" so we can fetch like real life.
mkdir remote.git && git -C remote.git init -q --bare -b main

mkdir work && cd work
git init -q -b main
git config user.email demo@local
git config user.name demo
git remote add origin "$DEMO/remote.git"

cat > utils.js <<'EOF'
function processUser(user) {
  return user;
}

module.exports = { processUser };
EOF
git add . && git commit -q -m "init"
git push -q -u origin main

# --- Day 1: both devs branch from main ---
git checkout -q -b feature/payments
cat > utils.js <<'EOF'
function processUser(user) {
  user.paymentId = 'pay_' + Math.random().toString(36).slice(2, 8);
  user.balance = 0;
  return user;
}

module.exports = { processUser };
EOF
git commit -qam "payments: add paymentId, balance"

# --- Day 2: payments merges to main ---
git checkout -q main
git merge -q --no-ff feature/payments -m "merge payments"
git push -q origin main

# --- Dev B was on feature/auth from day 1 ---
# Simulate by branching at the init commit.
INIT=$(git rev-list --max-parents=0 HEAD)
git checkout -q -b feature/auth "$INIT"
cat > utils.js <<'EOF'
function processUser(user) {
  user.token = 'tok_' + Math.random().toString(36).slice(2, 8);
  user.role = 'viewer';
  return user;
}

module.exports = { processUser };
EOF
git commit -qam "auth: add token, role"

# --- Day 2 morning: Dev B daily rebase ---
echo "=== Dev B daily rebase ==="
git fetch -q origin
echo "rebasing feature/auth onto origin/main..."
if git rebase origin/main; then :; else
  echo
  echo "--- small conflict surfaced (1 function, not 200 lines) ---"
  cat utils.js
  echo
  echo "=== Dev B resolves by merging logic — keep both sets of fields ==="
  cat > utils.js <<'EOF'
function processUser(user) {
  user.paymentId = 'pay_' + Math.random().toString(36).slice(2, 8);
  user.balance = 0;
  user.token = 'tok_' + Math.random().toString(36).slice(2, 8);
  user.role = 'viewer';
  return user;
}

module.exports = { processUser };
EOF
  git add utils.js
  git -c core.editor=true rebase --continue >/dev/null
fi

# --- Verify behavior ---
cat > app.js <<'EOF'
const { processUser } = require('./utils');
const u = processUser({ id: 1 });
const ok = u.token && u.paymentId && u.role && u.balance === 0;
console.log(u);
console.log(ok ? 'ALL FLOWS OK' : 'BROKEN');
process.exit(ok ? 0 : 1);
EOF

echo
echo "=== Run app.js — both flows work ==="
node app.js

echo
echo "Result: rebased early, conflict 4 lines, logic preserved, login + payment both work."
echo "Demo dir: $DEMO/work"
