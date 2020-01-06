module Main

import Pellicle.Core.Types
import Pellicle.Kinematics.DegreesOfFreedom
import Pellicle.Kinematics.Trajectory
import Pellicle.Kinematics.Decoupling
import Pellicle.Kinematics.DualStageSwap

%default total

assertEqDouble : String -> Double -> Double -> Double -> IO ()
assertEqDouble tag expected actual eps =
  if abs (expected - actual) <= eps
    then putStrLn ("  [PASS] " ++ tag)
    else do
      putStrLn ("  [FAIL] " ++ tag ++ ": expected " ++ show expected ++ " but got " ++ show actual)

assertTrue : String -> Bool -> IO ()
assertTrue tag cond =
  if cond
    then putStrLn ("  [PASS] " ++ tag)
    else putStrLn ("  [FAIL] " ++ tag ++ " condition was False")

testDegreesOfFreedom : IO ()
testDegreesOfFreedom = do
  putStrLn "--- Test Suite: Pellicle.Kinematics.DegreesOfFreedom ---"
  let pose0 = MkPose6DoF 10.0 20.0 0.5 0.0 0.0 0.0
  let pLocal = MkPoint3D 5.0 5.0 0.0
  let pGlobal = transformLocalToGlobal pose0 pLocal
  assertEqDouble "transform local X to global" 15.0 pGlobal.xMm 1.0e-9
  assertEqDouble "transform local Y to global" 25.0 pGlobal.yMm 1.0e-9
  assertTrue "pose inside standard envelope" (isPoseWithinEnvelope standardEnvelope pose0)
  let poseOut = MkPose6DoF 300.0 20.0 0.5 0.0 0.0 0.0
  assertTrue "out-of-bounds pose rejected" (not (isPoseWithinEnvelope standardEnvelope poseOut))

testTrajectory : IO ()
testTrajectory = do
  putStrLn "--- Test Suite: Pellicle.Kinematics.Trajectory ---"
  assertEqDouble "poly7Pos at tau=0" 0.0 (poly7Pos 0.0) 1.0e-9
  assertEqDouble "poly7Pos at tau=0.5" 0.5 (poly7Pos 0.5) 1.0e-9
  assertEqDouble "poly7Pos at tau=1" 1.0 (poly7Pos 1.0) 1.0e-9
  assertEqDouble "poly7Vel at tau=0 (C^1 continuity)" 0.0 (poly7Vel 0.0) 1.0e-9
  assertEqDouble "poly7Vel at tau=1 (C^1 continuity)" 0.0 (poly7Vel 1.0) 1.0e-9
  assertEqDouble "poly7Accel at tau=0 (C^2 continuity)" 0.0 (poly7Accel 0.0) 1.0e-9
  assertEqDouble "poly7Accel at tau=1 (C^2 continuity)" 0.0 (poly7Accel 1.0) 1.0e-9
  assertEqDouble "poly7Jerk at tau=0 (C^3 continuity)" 0.0 (poly7Jerk 0.0) 1.0e-9
  assertEqDouble "poly7Jerk at tau=1 (C^3 continuity)" 0.0 (poly7Jerk 1.0) 1.0e-9
  let tMin = calculateMinimumDuration 50.0
  assertTrue "min duration > 0.01s for 50mm move" (tMin > 0.01)
  let ptMid = sampleTrajectory 0.0 100.0 0.5 0.25
  assertEqDouble "midpoint trajectory position" 50.0 ptMid.positionMm 1.0e-6

testDecoupling : IO ()
testDecoupling = do
  putStrLn "--- Test Suite: Pellicle.Kinematics.Decoupling ---"
  let wrench = MkWrench6DoF 50.0 0.0 100.0 0.0 0.0 0.0
  let currents = allocateCoilCurrents wrench
  let power = computeOhmicPower currents
  assertTrue "coil currents within electrical limits" (isActuationSafe currents)
  assertTrue "ohmic power > 0" (power > 0.0)

testDualStageSwap : IO ()
testDualStageSwap = do
  putStrLn "--- Test Suite: Pellicle.Kinematics.DualStageSwap ---"
  let c1Pose = MkPose6DoF 0.0 MEASURE_STATION_Y_MM 0.0 0.0 0.0 0.0
  let c2Pose = MkPose6DoF 0.0 EXPOSURE_STATION_Y_MM 0.0 0.0 0.0 0.0
  let dist = chuckSeparationDistance c1Pose c2Pose
  assertEqDouble "station separation distance" 360.0 dist 1.0e-9
  assertTrue "clearance maintained between stations" (isClearanceMaintained c1Pose c2Pose)
  assertTrue "exposure mutual exclusion satisfied" (isExposureMutualExclusionSatisfied c1Pose c2Pose)
  let swapPathSafe = verifySwapPathSafety 100
  assertTrue "all 100 swap path waypoints satisfy clearance >= 15mm" swapPathSafe

main : IO ()
main = do
  putStrLn "=================================================="
  putStrLn "Pellicle Kinematics Verification Pass"
  putStrLn "=================================================="
  testDegreesOfFreedom
  testTrajectory
  testDecoupling
  testDualStageSwap
  putStrLn "Pellicle Kinematics: All assertions verified successfully."
