module Main

import Pellicle.Core.Types
import Pellicle.Metrology.Interferometer
import Pellicle.Metrology.Edlen
import Pellicle.Metrology.Encoder
import Pellicle.Metrology.Leveling

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

testInterferometer : IO ()
testInterferometer = do
  putStrLn "--- Test Suite: Pellicle.Metrology.Interferometer ---"
  let dNm = computeDisplacementNm HE_NE_WAVELENGTH_NM 1.0 10 0.0
  let expectedNm = 10.0 * (HE_NE_WAVELENGTH_NM / 2.0)
  assertEqDouble "displacement for 10 full fringes" expectedNm dNm 1.0e-6
  let v = computeDopplerVelocity HE_NE_WAVELENGTH_NM 1.0 1.0e6 4.16e6
  assertTrue "Doppler velocity > 0" (v > 0.0)
  let cluster = MkInterferometerCluster 1000.0 1000.0 2000.0 2000.0 0.0 0.0 0.0 SignalNominal
  let (xMm, yMm, _, _, _, _) = triangulate6DoF cluster
  assertEqDouble "triangulate X position" 0.001 xMm 1.0e-9
  assertEqDouble "triangulate Y position" 0.002 yMm 1.0e-9

testEdlen : IO ()
testEdlen = do
  putStrLn "--- Test Suite: Pellicle.Metrology.Edlen ---"
  let nAir = computeAirRefractiveIndex HE_NE_WAVELENGTH_NM nominalCleanroom
  -- Nominal refractive index of air around 633 nm is approx 1.00027137
  assertEqDouble "nominal air refractive index" 1.00027137 nAir 1.0e-4
  let lambdaAir = heNeAirWavelengthNm nominalCleanroom
  assertTrue "air wavelength smaller than vacuum wavelength" (lambdaAir < HE_NE_WAVELENGTH_NM)

testEncoder : IO ()
testEncoder = do
  putStrLn "--- Test Suite: Pellicle.Metrology.Encoder ---"
  let headReading = MkEncoderHeadReading 5 0.0 1.0 20.0
  let posNm = decodeEncoderPositionNm headReading
  assertEqDouble "decoded encoder position at 0 phase" 5000.0 posNm 1.0e-4
  let fused = fusePositionNm 0.6 1000.0 1100.0
  assertEqDouble "fused complementary position" 1040.0 fused 1.0e-6

testLeveling : IO ()
testLeveling = do
  putStrLn "--- Test Suite: Pellicle.Metrology.Leveling ---"
  -- Create samples from a known plane: z = 50.0 + 0.2 * y - 0.1 * x
  let s1 = MkHeightSample (-50.0) (-50.0) (50.0 + 0.2 * (-50.0) - 0.1 * (-50.0))
  let s2 = MkHeightSample 50.0 (-50.0) (50.0 + 0.2 * (-50.0) - 0.1 * 50.0)
  let s3 = MkHeightSample 50.0 50.0 (50.0 + 0.2 * 50.0 - 0.1 * 50.0)
  let s4 = MkHeightSample (-50.0) 50.0 (50.0 + 0.2 * 50.0 - 0.1 * (-50.0))
  let plane = fitLevelingPlane [s1, s2, s3, s4]
  assertEqDouble "fitted z0 parameter" 50.0 plane.z0Nm 1.0e-4
  assertEqDouble "fitted rx tilt parameter" 0.2 plane.rxUrad 1.0e-4
  assertEqDouble "fitted ry tilt parameter" 0.1 plane.ryUrad 1.0e-4
  assertEqDouble "plane fit residual RMS" 0.0 plane.residualRmsNm 1.0e-4
  assertTrue "fitted plane satisfies leveling tolerance" (isLevelingAcceptable plane)

main : IO ()
main = do
  putStrLn "=================================================="
  putStrLn "Pellicle Metrology Verification Pass"
  putStrLn "=================================================="
  testInterferometer
  testEdlen
  testEncoder
  testLeveling
  putStrLn "Pellicle Metrology: All assertions verified successfully."
