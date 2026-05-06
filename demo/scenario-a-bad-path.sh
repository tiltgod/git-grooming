#!/usr/bin/env bash
# Scenario A — bad path: late integration, text-merge succeeds, logic breaks.
# Run: bash scenario-a-bad-path.sh
set -e

DEMO=/tmp/grooming-demo-a
rm -rf "$DEMO" && mkdir -p "$DEMO" && cd "$DEMO"

git init -q -b main
git config user.email demo@local
git config user.name demo

cat > utils.js <<'EOF'
function processUser(user) {
  return user;
}

module.exports = { processUser };
EOF

cat > app.js <<'EOF'
const { processUser } = require('./utils');
const u = processUser({ id: 1 });
console.log('token =', u.token);
console.log('paymentId =', u.paymentId);
if (!u.token) { console.log('LOGIN BROKEN: token undefined'); process.exit(1); }
EOF

git add . && git commit -q -m "init"

# --- Dev A: payments branch ---
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

# --- Dev B: auth branch (off same main) ---
git checkout -q main
git checkout -q -b feature/auth
cat > utils.js <<'EOF'
function processUser(user) {
  user.token = 'tok_' + Math.random().toString(36).slice(2, 8);
  user.role = 'viewer';
  return user;
}

module.exports = { processUser };
EOF
git commit -qam "auth: add token, role"

# --- Day 4: A merges first, clean ---
git checkout -q main
git merge -q --no-ff feature/payments -m "merge payments"
echo
echo "=== Step 1: payments merged clean ==="
git log --oneline

# --- Then B merges, conflict ---
echo
echo "=== Step 2: try to merge auth into main ==="
if git merge --no-ff feature/auth -m "merge auth" 2>&1 | tail -5; then :; fi

echo
echo "--- conflict in utils.js: ---"
cat utils.js

# Simulate the "tired dev picks one side" resolution — keeps payments version.
echo
echo "=== Step 3: dev picks payments side to 'resolve' (typical late-night fix) ==="
cat > utils.js <<'EOF'
function processUser(user) {
  user.paymentId = 'pay_' + Math.random().toString(36).slice(2, 8);
  user.balance = 0;
  return user;
}

module.exports = { processUser };
EOF
git add utils.js
git commit -q -m "resolve conflict"
echo "merge committed. git says clean:"
git status -s

echo
echo "=== Step 4: run app.js — text merge ok, logic broken ==="
node app.js || true

echo
echo "Result: 'merge succeeded' but login broken. token never set."
echo "Demo dir: $DEMO"
