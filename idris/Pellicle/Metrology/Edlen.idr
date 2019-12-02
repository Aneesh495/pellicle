module Pellicle.Metrology.Edlen

import Pellicle.Core.Types

%default total

||| Atmospheric environmental telemetry for the scanner metrology chamber
public export
record AtmosphereConditions where
  constructor MkAtmosphereConditions
  tempCelsius : Double
  pressurePa : Double
  relativeHumidityPct : Double
  co2Ppm : Double

public export
Show AtmosphereConditions where
  show (MkAtmosphereConditions t p rh co2) =
    "T: " ++ show t ++ " C, P: " ++ show p ++ " Pa, RH: " ++ show rh ++ " %, CO2: " ++ show co2 ++ " ppm"

||| Nominal lithography cleanroom environmental setpoint
public export
nominalCleanroom : AtmosphereConditions
nominalCleanroom = MkAtmosphereConditions 20.000 101325.0 45.0 450.0

||| Compute vacuum wavenumber in micrometers^(-1)
||| sigma = 1.0 / lambda_um
public export
wavenumberUmInv : Double -> Double
wavenumberUmInv lambdaNm = 1000.0 / lambdaNm

||| Standard air refractivity (n_s - 1) * 1e8 for dry air at 15 C, 101325 Pa, 450 ppm CO2
||| Birch and Downs updated formula (1994)
public export
standardRefractivity : Double -> Double
standardRefractivity sigma =
  let sigma2 = sigma * sigma
      term1 = 8342.54
      term2 = 2406147.0 / (130.0 - sigma2)
      term3 = 15998.0 / (38.9 - sigma2)
  in (term1 + term2 + term3) * 1.0e-8

||| Saturation vapor pressure of water in Pa over liquid water (Sonntag formula)
public export
saturationVaporPressurePa : Double -> Double
saturationVaporPressurePa tempC =
  let tK = tempC + 273.15
      lnP = -6096.9385 / tK + 21.2409642 - 0.02711193 * tK + 0.00001673952 * tK * tK + 2.433502 * log tK
  in exp lnP

||| Compute partial water vapor pressure in Pa
public export
waterVaporPressurePa : Double -> Double -> Double
waterVaporPressurePa tempC rhPct =
  (rhPct / 100.0) * saturationVaporPressurePa tempC

||| Compute dynamic refractive index of air using the modified Edlen equation
||| Accurate to better than 1e-8 across typical cleanroom environmental envelopes
public export
computeAirRefractiveIndex : Double -> AtmosphereConditions -> Double
computeAirRefractiveIndex lambdaNm (MkAtmosphereConditions t p rh co2) =
  let sigma = wavenumberUmInv lambdaNm
      sigma2 = sigma * sigma
      nsMinus1 = standardRefractivity sigma
      -- Adjust for CO2 content
      nxMinus1 = nsMinus1 * (1.0 + 0.534e-6 * (co2 - 450.0))
      -- Adjust for temperature and pressure
      alpha = 0.003661
      beta = 1.0e-8 * (0.601 - 0.00972 * t) * p
      num = p * (1.0 + beta)
      den = 96095.43 * (1.0 + alpha * t)
      ntpMinus1 = nxMinus1 * (num / den)
      -- Adjust for water vapor humidity
      f = waterVaporPressurePa t rh
      vaporCorrection = - f * (3.7345 - 0.0401 * sigma2) * 1.0e-10
  in 1.0 + ntpMinus1 + vaporCorrection

||| Compute the wavelength of HeNe laser in air given current atmosphere
public export
heNeAirWavelengthNm : AtmosphereConditions -> Double
heNeAirWavelengthNm atm =
  let nAir = computeAirRefractiveIndex HE_NE_WAVELENGTH_NM atm
  in HE_NE_WAVELENGTH_NM / nAir

||| Scale factor to correct uncompensated displacement for atmospheric drift
||| corrected_d = raw_d * (n_nominal / n_current)
public export
edlenScaleCorrection : AtmosphereConditions -> AtmosphereConditions -> Double
edlenScaleCorrection nominal current =
  let nNom = computeAirRefractiveIndex HE_NE_WAVELENGTH_NM nominal
      nCur = computeAirRefractiveIndex HE_NE_WAVELENGTH_NM current
  in nNom / nCur
