module Pellicle.Metrology.Interferometer

import Pellicle.Core.Types

%default total

||| Raw heterodyne interferometer optical receiver reading
public export
record ReceiverReading where
  constructor MkReceiverReading
  fringeCount : Int
  fractionalPhaseRad : Double
  signalAmplitudeMv : Double
  refFrequencyHz : Double
  measFrequencyHz : Double

public export
Show ReceiverReading where
  show (MkReceiverReading fringes phase amp fRef fMeas) =
    "Fringes: " ++ show fringes ++ ", Phase: " ++ show phase ++ " rad, Amp: " ++ show amp ++ " mV"

||| Quality status of an interferometer optical channel
public export
data SignalStatus = SignalNominal | SignalDegraded | SignalLost

public export
Eq SignalStatus where
  SignalNominal == SignalNominal = True
  SignalDegraded == SignalDegraded = True
  SignalLost == SignalLost = True
  _ == _ = False

public export
Show SignalStatus where
  show SignalNominal = "NOMINAL"
  show SignalDegraded = "DEGRADED"
  show SignalLost = "LOSS_OF_SIGNAL"

||| Check whether signal amplitude meets minimum threshold (50 mV for loss, 200 mV for nominal)
public export
checkSignalStatus : Double -> SignalStatus
checkSignalStatus amp =
  if amp < 50.0 then SignalLost
  else if amp < 200.0 then SignalDegraded
  else SignalNominal

||| Compute optical displacement in nanometers given fringe count, phase, and refractive index
||| Formula: d = (lambda_0 / (2 * n_air)) * (fringes + phase / (2 * pi))
public export
computeDisplacementNm : (lambda0Nm : Double) -> (nAir : Double) -> (fringes : Int) -> (phaseRad : Double) -> Double
computeDisplacementNm lambda0 nAir fringes phase =
  let piVal = 3.141592653589793
      effectiveLambda = lambda0 / (2.0 * nAir)
      fringeFraction = cast fringes + (phase / (2.0 * piVal))
  in effectiveLambda * fringeFraction

||| Estimate instantaneous Doppler velocity in m/s from optical heterodyne beat frequency shift
||| Delta f = 2 * v * n_air / lambda_0  =>  v = (Delta f * lambda_0) / (2 * n_air)
public export
computeDopplerVelocity : (lambda0Nm : Double) -> (nAir : Double) -> (fRefHz : Double) -> (fMeasHz : Double) -> Double
computeDopplerVelocity lambda0 nAir fRef fMeas =
  let deltaF = fMeas - fRef
      lambdaM = lambda0 * 1.0e-9
  in (deltaF * lambdaM) / (2.0 * nAir)

||| Seven-axis interferometer array reading for a 6-DoF wafer chuck
||| Axes: X1, X2 (for X and Rz), Y1, Y2 (for Y and Rz), Z1, Z2, Z3 (for Z, Rx, Ry)
public export
record InterferometerCluster where
  constructor MkInterferometerCluster
  axisX1Nm : Double
  axisX2Nm : Double
  axisY1Nm : Double
  axisY2Nm : Double
  axisZ1Nm : Double
  axisZ2Nm : Double
  axisZ3Nm : Double
  status : SignalStatus

||| Baseline separation between parallel interferometer beams in millimeters
public export
INTERF_BASELINE_MM : Double
INTERF_BASELINE_MM = 120.0

||| Triangulate 6-DoF rigid body state from the 7-axis interferometer cluster
||| Returns (X mm, Y mm, Z mm, Rx urad, Ry urad, Rz urad)
public export
triangulate6DoF : InterferometerCluster -> (Double, Double, Double, Double, Double, Double)
triangulate6DoF cluster =
  let xNm = (cluster.axisX1Nm + cluster.axisX2Nm) / 2.0
      yNm = (cluster.axisY1Nm + cluster.axisY2Nm) / 2.0
      zNm = (cluster.axisZ1Nm + cluster.axisZ2Nm + cluster.axisZ3Nm) / 3.0
      rzRad = (cluster.axisX2Nm - cluster.axisX1Nm) / (INTERF_BASELINE_MM * 1.0e6)
      rxRad = (cluster.axisZ2Nm - cluster.axisZ1Nm) / (INTERF_BASELINE_MM * 1.0e6)
      ryRad = (cluster.axisZ3Nm - cluster.axisZ1Nm) / (INTERF_BASELINE_MM * 1.0e6)
      xMm = nmToMm xNm
      yMm = nmToMm yNm
      zMm = nmToMm zNm
      rxUrad = rxRad * 1.0e6
      ryUrad = ryRad * 1.0e6
      rzUrad = rzRad * 1.0e6
  in (xMm, yMm, zMm, rxUrad, ryUrad, rzUrad)
