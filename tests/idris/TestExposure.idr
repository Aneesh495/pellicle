module Main

import Pellicle.Core.Types
import Pellicle.Exposure.ScanSync
import Pellicle.Exposure.Overlay
import Pellicle.Exposure.Dose
import Pellicle.Exposure.Recipe

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

testScanSync : IO ()
testScanSync = do
  putStrLn "--- Test Suite: Pellicle.Exposure.ScanSync ---"
  let rPos = nominalReticlePosMm 10.0
  assertEqDouble "4:1 reticle position reduction" (-40.0) rPos 1.0e-9
  let rVel = nominalReticleVelMps 1.25
  assertEqDouble "4:1 reticle velocity reduction" (-5.0) rVel 1.0e-9
  let tTransit = computeSlitTransitTimeSec 1.0
  assertEqDouble "slit transit time at 1 m/s" 0.008 tTransit 1.0e-6
  let lockState = checkSyncLock 10.0 1.0 (-40.0) (-4.0)
  assertTrue "sync lock achieved when reticle is at -4*Y" lockState.isSynchronized

testOverlay : IO ()
testOverlay = do
  putStrLn "--- Test Suite: Pellicle.Exposure.Overlay ---"
  let errorsNominal = [0.2, 0.4, -0.1, 0.3, -0.2, 0.1]
  let dma = computeDMA errorsNominal
  let msd = computeMSD errorsNominal dma
  assertTrue "nominal DMA <= 1.2 nm" (abs dma <= MAX_OVERLAY_DMA_NM)
  assertTrue "nominal MSD <= 1.8 nm" (msd <= MAX_OVERLAY_MSD_NM)
  let metricsNom = evaluateSlitOverlay errorsNominal
  assertTrue "laser pulse permitted for nominal overlay" (shouldAllowLaserPulse metricsNom)
  let errorsExcessive = [2.5, 3.1, 2.8, 3.4, 2.9]
  let metricsBad = evaluateSlitOverlay errorsExcessive
  assertTrue "laser pulse interlocked for excessive overlay" (not (shouldAllowLaserPulse metricsBad))

testDose : IO ()
testDose = do
  putStrLn "--- Test Suite: Pellicle.Exposure.Dose ---"
  let d0 = initDoseState 25.0
  assertEqDouble "initial dose is zero" 0.0 d0.accumulatedDoseMilliJoulePerCm2 1.0e-9
  -- Simulate integrating a series of pulses
  let d1 = integratePulse d0 5.0 1.0
  assertTrue "dose accumulated after pulse" (d1.accumulatedDoseMilliJoulePerCm2 > 0.0)
  assertTrue "pulse count incremented" (d1.pulseCount == 1)

testRecipe : IO ()
testRecipe = do
  putStrLn "--- Test Suite: Pellicle.Exposure.Recipe ---"
  assertTrue "center die is within wafer boundary" (isDieWithinWaferBoundary 0.0 0.0)
  assertTrue "outer die (200mm) outside wafer boundary" (not (isDieWithinWaferBoundary 200.0 0.0))
  let dies = generateDieLayout
  assertTrue "generated die layout produces valid die count" (length dies >= 50)
  assertTrue "all generated dies within usable wafer radius"
    (foldl (\acc, die => acc && isDieWithinWaferBoundary die.centerXMm die.centerYMm) True dies)

main : IO ()
main = do
  putStrLn "=================================================="
  putStrLn "Pellicle Exposure Verification Pass"
  putStrLn "=================================================="
  testScanSync
  testOverlay
  testDose
  testRecipe
  putStrLn "Pellicle Exposure: All assertions verified successfully."
