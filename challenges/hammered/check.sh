#!/usr/bin/env bash
# Runs in /root. Exit 0 = solved.
# The answers are stored as hashes, so reading this file doesn't give them away.
declare -A want=(
  [1]=d6ed477466727139292f1dfd1032f5f2eaf6c3c3431778db3bf2ce70ba4d2001
  [2]=d59b6c778225d74d04b12abdd8dfc196d8602d164d3343a4b2195fdb4e54d31f
  [3]=62dbf79ce516a71c42187f7bcf1616a6258706da7ab48317780dd223385a1bc6
  [4]=5a23e96a12312c41555013ed2a5b40cbce5cb9ba180ec0a2d1cc77cbe0e39f72
  [5]=c361e7d02179e9b45e9796916af36838788d2a057deaff90ce34c2cf52f8643a
  [6]=570e7c9ab48193dbebe18c750949c55cf5077dd5e0f75528876eda8a0fdda303
  [7]=02cc100736c73d8bf75eb76852460fcf9132d2020f9a86db5c17e049c9d10883
  [8]=20f3d1de30c2838fb845d624b49c2197c4c9945371924203029e0d001ae9d70b
  [9]=1f1cb2fad19686779a60a4e0fdf45d858404114de6f3873b7d77d46832272c1b
  [10]=592e1f0cf5f0604e04de2c06182a4e9552ff1f88808bfba1f962e77fc62ec7a7
  [11]=b91e4e76396376c1a9e8b2eb589a1fc8cefe0b7385b101f9a3e746324416bfa3
  [12]=e8e179aa3e7c8eabb04982888d8e9d6bf6662a5e93e7ede9f4023fc5a99d8b85
)

file=/root/answers.txt
[ -f "$file" ] || { echo "failed: write your answers to $file, one per line, as 'N: answer'"; exit 1; }

norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' \t' ' ' | sed 's/^ //; s/ $//'; }

right=0; wrong=()
for n in $(seq 1 12); do
  given=$(grep -E "^[[:space:]]*$n[[:space:]]*:" "$file" | head -n 1)
  given=$(norm "${given#*:}")
  if [ -n "$given" ] && [ "$(printf '%s:%s' "$n" "$given" | sha256sum | cut -c1-64)" = "${want[$n]}" ]; then
    right=$((right + 1))
  else
    wrong+=("$n")
  fi
done

if [ "$right" -lt 12 ]; then
  echo "failed: $right of 12 answers are right"
  echo "  not right yet: ${wrong[*]}"
  exit 1
fi
echo "all 12 answers are right: case closed"
