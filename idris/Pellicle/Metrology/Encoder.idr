module Pellicle.Metrology.Encoder

import Pellicle.Core.Types

%default total

||| Grid grating spatial pitch in nanometers (typically 1.0 um = 1000 nm)
public export
ENCODER_PITCH_NM : Double
ENCODER_PITCH_NM = 1000.0

||| Thermal expansion coefficient of Zerodur grid scale substrate in ppm/K (1e-6 / K)
public export
ZERODUR_CTE_PPM_PER_K : Double
ZERODUR_CTE_PPM_PER_K = 0.020

||| Compute two-argument arctangent atan2(y, x) using standard quadrant rules
public export
atan2Double : Double -> Double -> Double
atan2Double y x =
  let piVal = 3.141592653589793
  in if x > 0.0 then atan (y / x)
     else if x < 0.0 && y >= 0.0 then atan (y / x) + piVal
     else if x < 0.0 && y < 0.0 then atan (y / x) - piVal
     else if x == 0.0 && y > 0.0 then piVal / 2.0
     else if x == 0.0 && y < 0.0 then -(piVal / 2.0)
     else 0.0

||| Raw optical reading head quadrature signal
public export
record EncoderHeadReading where
  constructor MkEncoderHeadReading
  gridPitchCount : Int
  sineVolts : Double
  cosineVolts : Double
  temperatureCelsius : Double

public export
Show EncoderHeadReading where
  show (MkEncoderHeadReading counts s c t) =
    "Counts: " ++ show counts ++ ", Sin: " ++ show s ++ " V, Cos: " ++ show c ++ " V, T: " ++ show t ++ " C"

||| Compute sub-pitch phase in radians using arctan2 of quadrature signals
public export
encoderPhaseRad : Double -> Double -> Double
encoderPhaseRad sinV cosV =
  atan2Double sinV cosV

||| Compute thermal grid expansion scale factor relative to 20.0 C reference
||| scale = 1.0 + CTE * (T - 20.0) * 1e-6
public export
gridThermalScale : Double -> Double
gridThermalScale tempC =
  let deltaT = tempC - 20.000
  in 1.0 + (ZERODUR_CTE_PPM_PER_K * 1.0e-6 * deltaT)

||| Decode single encoder head position in nanometers
||| pos_nm = (pitch_count * pitch_nm + (phase / (2 * pi)) * pitch_nm) * thermal_scale
public export
decodeEncoderPositionNm : EncoderHeadReading -> Double
decodeEncoderPositionNm (MkEncoderHeadReading counts sinV cosV tempC) =
  let piVal = 3.141592653589793
      phase = encoderPhaseRad sinV cosV
      -- Normalize phase from [-pi, pi] to [0, 2*pi]
      normPhase = if phase < 0.0 then phase + (2.0 * piVal) else phase
      fractionalPitch = normPhase / (2.0 * piVal)
      rawNm = (cast counts + fractionalPitch) * ENCODER_PITCH_NM
      scale = gridThermalScale tempC
  in rawNm * scale

||| Quad-head 2D encoder cluster mounted under the wafer chuck
||| Heads H1 and H2 measure X, Heads H3 and H4 measure Y
public export
record QuadEncoderCluster where
  constructor MkQuadEncoderCluster
  headX1 : EncoderHeadReading
  headX2 : EncoderHeadReading
  headY1 : EncoderHeadReading
  headY2 : EncoderHeadReading

||| Sensor fusion between laser interferometer reading and optical grid encoder reading
||| Weighted complementary filter: pos_fused = w_interf * pos_interf + (1 - w_interf) * pos_encoder
public export
fusePositionNm : (wInterf : Double) -> (posInterfNm : Double) -> (posEncoderNm : Double) -> Double
fusePositionNm wInterf posInterf posEncoder =
  let w = if wInterf < 0.0 then 0.0 else if wInterf > 1.0 then 1.0 else wInterf
  in (w * posInterf) + ((1.0 - w) * posEncoder)
