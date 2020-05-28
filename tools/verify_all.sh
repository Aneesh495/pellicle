#!/usr/bin/env bash
# Pellicle Standalone End-to-End Verification Driver
# Compliant with strict POSIX bash standards

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

echo "================================================================================"
echo "  PELLICLE: Comprehensive End-to-End Multi-Language Verification Pass"
echo "================================================================================"

echo "[1/7] Scanning codebase for typography invariant violations..."
python3 tools/lint_no_em_dash.py

echo "[2/7] Compiling verified Idris 2 package and safety kernel..."
idris2 --build pellicle.ipkg

echo "[3/7] Compiling C17 fastpath acceleration engine..."
make -C c_fastpath clean
make -C c_fastpath

echo "[4/7] Executing pure Idris 2 formal proof and property test suites..."
IDRIS2_PATH="idris" idris2 tests/idris/TestCore.idr -o test_core
./build/exec/test_core

IDRIS2_PATH="idris" idris2 tests/idris/TestMetrology.idr -o test_metrology
./build/exec/test_metrology

IDRIS2_PATH="idris" idris2 tests/idris/TestKinematics.idr -o test_kinematics
./build/exec/test_kinematics

IDRIS2_PATH="idris" idris2 tests/idris/TestExposure.idr -o test_exposure
./build/exec/test_exposure

IDRIS2_PATH="idris" idris2 tests/idris/TestProof.idr -o test_proof
./build/exec/test_proof

echo "[5/7] Executing C17 unit tests and numerical equivalence suite..."
make -C tests/c clean
make -C tests/c test
python3 tests/c/test_equivalence.py

echo "[6/7] Executing Python socket IPC, fault drills, and regression suites..."
python3 tests/integration/test_suite.py
python3 tests/integration/test_fault_drills.py
python3 tests/integration/test_regressions.py

echo "[7/7] Running scanner throughput and servo latency benchmark..."
python3 tools/bench_throughput.py

echo "================================================================================"
echo "  VERIFICATION COMPLETE: ALL 100+ TESTS AND PROOFS PASSED (0 FAILURES)"
echo "================================================================================"
