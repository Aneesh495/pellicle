module Pellicle.Metrology.Leveling

import Data.Vect
import Pellicle.Core.Types

%default total

||| Single height measurement sample on the wafer surface
public export
record HeightSample where
  constructor MkHeightSample
  xMm : Double
  yMm : Double
  zNm : Double

public export
Show HeightSample where
  show (MkHeightSample x y z) =
    "(" ++ show x ++ ", " ++ show y ++ ") mm -> " ++ show z ++ " nm"

||| Best-fit leveling plane parameters: z(x, y) = z0 + rx * y - ry * x
||| z0 in nm, rx in urad (slope in nm/mm), ry in urad (slope in nm/mm)
public export
record LevelingPlane where
  constructor MkLevelingPlane
  z0Nm : Double
  rxUrad : Double
  ryUrad : Double
  residualRmsNm : Double
  peakToValleyNm : Double

public export
Show LevelingPlane where
  show (MkLevelingPlane z0 rx ry rms pv) =
    "Plane: z0=" ++ show z0 ++ " nm, Rx=" ++ show rx ++ " urad, Ry=" ++ show ry ++ " urad, RMS=" ++ show rms ++ " nm, PV=" ++ show pv ++ " nm"

||| Evaluate leveling plane height in nm at any coordinate (x, y) in mm
public export
evaluatePlaneNm : LevelingPlane -> Double -> Double -> Double
evaluatePlaneNm (MkLevelingPlane z0 rx ry _ _) xMm yMm =
  z0 + (rx * yMm) - (ry * xMm)

||| Helper accumulator for least-squares plane fitting
record PlaneSums where
  constructor MkPlaneSums
  count : Double
  sumX : Double
  sumY : Double
  sumZ : Double
  sumXX : Double
  sumYY : Double
  sumXY : Double
  sumXZ : Double
  sumYZ : Double

zeroSums : PlaneSums
zeroSums = MkPlaneSums 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0

accumulateSample : HeightSample -> PlaneSums -> PlaneSums
accumulateSample (MkHeightSample x y z) (MkPlaneSums n sx sy sz sxx syy sxy sxz syz) =
  MkPlaneSums
    (n + 1.0)
    (sx + x)
    (sy + y)
    (sz + z)
    (sxx + x * x)
    (syy + y * y)
    (sxy + x * y)
    (sxz + x * z)
    (syz + y * z)

||| Solve 3x3 linear system for plane parameters using Cramer's rule
||| Matrix:
||| [ sxx  sxy  sx ] [ -ry ]   [ sxz ]
||| [ sxy  syy  sy ] [  rx ] = [ syz ]
||| [ sx   sy   n  ] [  z0 ]   [ sz  ]
det3x3 : (a11, a12, a13 : Double) ->
         (a21, a22, a23 : Double) ->
         (a31, a32, a33 : Double) -> Double
det3x3 a11 a12 a13 a21 a22 a23 a31 a32 a33 =
  a11 * (a22 * a33 - a23 * a32) -
  a12 * (a21 * a33 - a23 * a31) +
  a13 * (a21 * a32 - a22 * a31)

solvePlaneParams : PlaneSums -> (Double, Double, Double)
solvePlaneParams s =
  let detA = det3x3 s.sumXX s.sumXY s.sumX
                    s.sumXY s.sumYY s.sumY
                    s.sumX  s.sumY  s.count
  in if abs detA < 1.0e-12
       then (s.sumZ / s.count, 0.0, 0.0)
       else
         let detNegRy = det3x3 s.sumXZ s.sumXY s.sumX
                               s.sumYZ s.sumYY s.sumY
                               s.sumZ  s.sumY  s.count
             detRx    = det3x3 s.sumXX s.sumXZ s.sumX
                               s.sumXY s.sumYZ s.sumY
                               s.sumX  s.sumZ  s.count
             detZ0    = det3x3 s.sumXX s.sumXY s.sumXZ
                               s.sumXY s.sumYY s.sumYZ
                               s.sumX  s.sumY  s.sumZ
             negRy = detNegRy / detA
             rx    = detRx / detA
             z0    = detZ0 / detA
             ry    = -negRy
         in (z0, rx, ry)

||| Compute RMS error and peak-to-valley across samples
computeResidualMetrics : List HeightSample -> Double -> Double -> Double -> (Double, Double)
computeResidualMetrics samples z0 rx ry =
  let residuals = map (\(MkHeightSample x y z) => z - (z0 + rx * y - ry * x)) samples
      n = cast (length residuals)
  in if n == 0.0
       then (0.0, 0.0)
       else
         let sumSq = foldl (\acc, r => acc + r * r) 0.0 residuals
             rms = sqrt (sumSq / n)
             minR = foldl (\acc, r => if r < acc then r else acc) 1.0e9 residuals
             maxR = foldl (\acc, r => if r > acc then r else acc) (-1.0e9) residuals
             pv = maxR - minR
         in (rms, pv)

||| Fit leveling plane to a collection of surface height measurement samples
public export
fitLevelingPlane : List HeightSample -> LevelingPlane
fitLevelingPlane samples =
  if null samples
    then MkLevelingPlane 0.0 0.0 0.0 0.0 0.0
    else
      let sums = foldl (flip accumulateSample) zeroSums samples
          (z0, rx, ry) = solvePlaneParams sums
          (rms, pv) = computeResidualMetrics samples z0 rx ry
      in MkLevelingPlane z0 rx ry rms pv

||| Check whether wafer surface leveling meets depth-of-focus tolerance (PV <= 120 nm)
public export
isLevelingAcceptable : LevelingPlane -> Bool
isLevelingAcceptable plane =
  plane.peakToValleyNm <= 120.0
