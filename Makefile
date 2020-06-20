# Pellicle: High-Assurance Photolithography Wafer Scanner Control System
# Unified Top-Level Multi-Language Build & Verification Harness

.PHONY: all idris c test bench sim viz topo lint clean

all: idris c

idris:
	idris2 --build pellicle.ipkg
	IDRIS2_PATH="idris" idris2 tests/idris/TestCore.idr -o test_core
	IDRIS2_PATH="idris" idris2 tests/idris/TestMetrology.idr -o test_metrology
	IDRIS2_PATH="idris" idris2 tests/idris/TestKinematics.idr -o test_kinematics
	IDRIS2_PATH="idris" idris2 tests/idris/TestExposure.idr -o test_exposure
	IDRIS2_PATH="idris" idris2 tests/idris/TestProof.idr -o test_proof
	IDRIS2_PATH="idris" idris2 tests/idris/TestStress.idr -o test_stress

c:
	$(MAKE) -C c_fastpath
	$(MAKE) -C tests/c

test: all lint
	./build/exec/test_core
	./build/exec/test_metrology
	./build/exec/test_kinematics
	./build/exec/test_exposure
	./build/exec/test_proof
	./build/exec/test_stress
	./bin/test_fastpath
	python3 tests/c/test_equivalence.py
	python3 tests/integration/test_suite.py
	python3 tests/integration/test_fault_drills.py
	python3 tests/integration/test_regressions.py
	@echo "\n========================================================"
	@echo "ALL PELLICLE MULTI-TIER VERIFICATION SUITES PASSED (0 FAILS)"
	@echo "========================================================\n"

bench: c
	python3 tools/bench_throughput.py

sim: idris
	./build/exec/pellicle

viz:
	python3 tools/wafer_visualizer.py

topo:
	python3 tools/plot_topography.py

lint:
	python3 tools/lint_no_em_dash.py

clean:
	rm -rf build bin
	$(MAKE) -C c_fastpath clean
	$(MAKE) -C tests/c clean
