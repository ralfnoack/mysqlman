#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Parse global flags for config and log file override
while [[ "$1" =~ ^--(debug|parallel)$ ]]; do
  case "$1" in
    --debug)
      DEBUG=1; shift 1;;
    --parallel)
      PARALLEL=1; shift 1;;
  esac
done

success=0
fail=0
unknown=0
total=0

if [[ $PARALLEL -eq 1 ]]; then
  echo "Running tests in parallel..."
  declare -A results
  declare -A outputs
  pids=()
  i=0
  for t in tests/*.sh; do
    (
      output=$(bash "$t")
      if echo "$output" | grep -q '^OK$'; then
        echo "OK"
        echo "$output" > ".test_out_$i"
      elif echo "$output" | grep -q '^FAIL$'; then
        echo "FAIL"
        echo "$output" > ".test_out_$i"
      else
        echo "UNKNOWN"
        echo "$output" > ".test_out_$i"
      fi
    ) &
    pids+=("$!")
    results[$i]="$t"
    ((i++))
  done
  # Wait for all
  for idx in "${!pids[@]}"; do
    pid=${pids[$idx]}
    wait $pid
    status=$(cat ".test_out_$idx" | head -n1)
    output=$(cat ".test_out_$idx")
    t=${results[$idx]}
    echo "===== Running $t ====="
    if [[ "$status" == "OK" ]]; then
      echo -e "${GREEN}✔ OK${NC}"
      ((success++))
    elif [[ "$status" == "FAIL" ]]; then
      echo -e "${RED}✗ FAIL${NC}"
      echo "$output"
      ((fail++))
    else
      echo -e "${RED}✗ UNKNOWN RESULT${NC}"
      echo "$output"
      ((unknown++))
    fi
    ((total++))
    echo

    if [[ $DEBUG -eq 1 ]]; then
      echo "======================"
      cat ".test_out_$idx"
      echo "======================"
    else
      rm -f ".test_out_$idx"
    fi


  done
else
  echo "Running tests sequentially..."
  for t in tests/*.sh; do
    echo "===== Running $t ====="
    if [[ $DEBUG -eq 1 ]]; then
      bash "$t"
      result=${PIPESTATUS[0]}
      output=$(bash "$t")
    else
      output=$(bash "$t")
    fi
    if echo "$output" | grep -q '^OK$'; then
      echo -e "${GREEN}✔ OK${NC}"
      ((success++))
    elif echo "$output" | grep -q '^FAIL$'; then
      echo -e "${RED}✗ FAIL${NC}"
      echo "$output"
      ((fail++))
    else
      echo -e "${RED}✗ UNKNOWN RESULT${NC}"
      echo "$output"
      ((unknown++))
    fi
    ((total++))
    echo
  done
fi

echo ""
echo "===== Test Summary ====="
echo -e "${GREEN}Success: $success${NC}"
echo -e "${RED}Failures: $fail${NC}"
echo -e "${RED}Unknown: $unknown${NC}"
echo "Total: $total"
echo "========================"