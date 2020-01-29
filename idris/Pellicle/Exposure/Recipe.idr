module Pellicle.Exposure.Recipe

import Data.List
import Pellicle.Core.Types
import Pellicle.Core.Bounded

%default total

||| Standard maximum exposure field width in mm (reticle slit width)
public export
MAX_FIELD_WIDTH_MM : Double
MAX_FIELD_WIDTH_MM = 26.0

||| Standard maximum exposure field height in mm (scanning length)
public export
MAX_FIELD_HEIGHT_MM : Double
MAX_FIELD_HEIGHT_MM = 33.0

||| Wafer physical edge exclusion border in mm (no dies exposed within this ring)
public export
EDGE_EXCLUSION_MM : Double
EDGE_EXCLUSION_MM = 3.0

||| Usable wafer exposure radius in mm
public export
USABLE_WAFER_RADIUS_MM : Double
USABLE_WAFER_RADIUS_MM = (WAFER_DIAMETER_MM / 2.0) - EDGE_EXCLUSION_MM

||| Scan direction for serpentine snake trajectory
public export
data ScanDirection = ScanPositiveY | ScanNegativeY

public export
Eq ScanDirection where
  ScanPositiveY == ScanPositiveY = True
  ScanNegativeY == ScanNegativeY = True
  _ == _ = False

public export
Show ScanDirection where
  show ScanPositiveY = "SCAN_+Y"
  show ScanNegativeY = "SCAN_-Y"

||| An individual exposure die field on the 300mm wafer
public export
record DieField where
  constructor MkDieField
  dieIndex : Nat
  colIndex : Int
  rowIndex : Int
  centerXMm : Double
  centerYMm : Double
  scanDir : ScanDirection
  isFullyOnWafer : Bool

public export
Show DieField where
  show (MkDieField idx col row x y dir onW) =
    "Die#" ++ show idx ++ " [Col=" ++ show col ++ ", Row=" ++ show row ++ "]: (" ++
    show x ++ ", " ++ show y ++ ") mm, Dir=" ++ show dir

||| Candidate die field geometry evaluated prior to boundary filtering
record CandidateDie where
  constructor MkCandidateDie
  cCol : Int
  cRow : Int
  cXMm : Double
  cYMm : Double
  cDir : ScanDirection
  cOnWafer : Bool

||| Check if all four corners of a die field lie within the usable wafer radius
public export
isDieWithinWaferBoundary : (centerXMm : Double) -> (centerYMm : Double) -> Bool
isDieWithinWaferBoundary cx cy =
  let halfW = MAX_FIELD_WIDTH_MM / 2.0
      halfH = MAX_FIELD_HEIGHT_MM / 2.0
      rLimit = USABLE_WAFER_RADIUS_MM
      -- Check all four corners
      c1 = (cx - halfW) * (cx - halfW) + (cy - halfH) * (cy - halfH) <= rLimit * rLimit
      c2 = (cx + halfW) * (cx + halfW) + (cy - halfH) * (cy - halfH) <= rLimit * rLimit
      c3 = (cx - halfW) * (cx - halfW) + (cy + halfH) * (cy + halfH) <= rLimit * rLimit
      c4 = (cx + halfW) * (cx + halfW) + (cy + halfH) * (cy + halfH) <= rLimit * rLimit
  in c1 && c2 && c3 && c4

||| Generate a candidate die for given column and row
candidateForColRow : Int -> Int -> CandidateDie
candidateForColRow c r =
  let cx = cast c * MAX_FIELD_WIDTH_MM
      cy = cast r * MAX_FIELD_HEIGHT_MM
      dir = if mod (abs c) 2 == 0 then ScanPositiveY else ScanNegativeY
      onW = isDieWithinWaferBoundary cx cy
  in MkCandidateDie c r cx cy dir onW

||| Generate a serpentine snake die layout list for a 300mm wafer
public export
generateDieLayout : List DieField
generateDieLayout =
  let colIndices = [-5 .. 5]
      rowIndices = [-4 .. 4]
      allCandidates = concatMap (\c => map (candidateForColRow c) rowIndices) colIndices
      validCandidates = filter cOnWafer allCandidates
      indexed = zip [1 .. length validCandidates] validCandidates
  in map (\(idx, cand) =>
       MkDieField idx cand.cCol cand.cRow cand.cXMm cand.cYMm cand.cDir cand.cOnWafer) indexed

||| Complete recipe definition for a production lot of wafers
public export
record ExposureRecipe where
  constructor MkExposureRecipe
  recipeId : String
  laserSource : LaserSource
  targetDoseMilliJoulePerCm2 : Double
  numericalAperture : Double
  scanVelocityMps : Double
  fieldLayout : List DieField

public export
Show ExposureRecipe where
  show (MkExposureRecipe id src dose na v fields) =
    "Recipe[" ++ id ++ ", " ++ show src ++ ", Dose=" ++ show dose ++ "mJ/cm2, NA=" ++
    show na ++ ", Vel=" ++ show v ++ "m/s, Dies=" ++ show (length fields) ++ "]"

||| Standard 7nm logic test vehicle exposure recipe
public export
standardLogicRecipe : ExposureRecipe
standardLogicRecipe =
  MkExposureRecipe
    "RECIPE_7NM_LOGIC_TEST"
    ArFi
    25.0
    1.35
    1.25
    generateDieLayout
