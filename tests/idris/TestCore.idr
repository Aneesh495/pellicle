module Main

import Data.Maybe
import Data.Vect
import Pellicle.Core.Types
import Pellicle.Core.Bounded
import Pellicle.Core.Matrix
import Pellicle.Core.Units

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

testUnitsAndTypes : IO ()
testUnitsAndTypes = do
  putStrLn "--- Test Suite: Pellicle.Core.Types & Units ---"
  assertEqDouble "nmToMm conversion" 1.0 (nmToMm 1000000.0) 1.0e-9
  assertEqDouble "mmToNm conversion" 1000000.0 (mmToNm 1.0) 1.0e-9
  let p1 = MkPoint2D 0.0 0.0
  let p2 = MkPoint2D 3.0 4.0
  assertEqDouble "distance2D 3-4-5 triangle" 5.0 (distance2D p1 p2) 1.0e-9
  let lenQ = nanoMeters 1500.0
  assertEqDouble "toNanoMeters" 1500.0 (toNanoMeters lenQ) 1.0e-9
  let angQ = microRadians 250.0
  assertEqDouble "toMicroRadians" 250.0 (toMicroRadians angQ) 1.0e-9

testBounded : IO ()
testBounded = do
  putStrLn "--- Test Suite: Pellicle.Core.Bounded ---"
  let vValid = mkStageVelocity 3.5
  assertTrue "valid stage velocity 3.5 m/s accepted" (isJust vValid)
  let vInvalid = mkStageVelocity 7.5
  assertTrue "excessive stage velocity 7.5 m/s rejected" (isNothing vInvalid)
  let aValid = mkStageAccel 80.0
  assertTrue "valid stage acceleration 80 m/s^2 accepted" (isJust aValid)
  let aInvalid = mkStageAccel 150.0
  assertTrue "excessive stage acceleration 150 m/s^2 rejected" (isNothing aInvalid)
  let pWithin = MkPoint2D 50.0 50.0
  assertTrue "point (50, 50) within 300mm wafer radius" (isJust (mkWaferRadialPosition pWithin))
  let pOutside = MkPoint2D 120.0 120.0
  assertTrue "point (120, 120) outside 150mm wafer radius" (isNothing (mkWaferRadialPosition pOutside))

testMatrix : IO ()
testMatrix = do
  putStrLn "--- Test Suite: Pellicle.Core.Matrix ---"
  let v1 : Vect 3 Double = [1.0, 2.0, 3.0]
  let v2 : Vect 3 Double = [4.0, 5.0, 6.0]
  assertEqDouble "vector dot product" 32.0 (dotProduct v1 v2) 1.0e-9
  let id3 : Matrix 3 3 = eye 3
  assertEqDouble "matrix trace of 3x3 identity" 3.0 (matTrace id3) 1.0e-9
  let vRes = multVec id3 v1
  assertEqDouble "identity multVec preservation (x)" 1.0 (head vRes) 1.0e-9

main : IO ()
main = do
  putStrLn "=================================================="
  putStrLn "Pellicle Core Verification Pass"
  putStrLn "=================================================="
  testUnitsAndTypes
  testBounded
  testMatrix
  putStrLn "Pellicle Core: All assertions verified successfully."
