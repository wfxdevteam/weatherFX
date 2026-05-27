-- physical atmosphere definition
-- all lighting will attempt to derive from this
-- params from Hillaire 2020 / Bruneton & Neyret 2008.
-- https://inria.hal.science/inria-00288758/document

return {
  -- rayleigh scattering


  rayleighBeta = vec3(5.802e-6, 13.558e-6, 33.100e-6),
  rayleighH = 8500.0, -- m, scale height

  -- mie scattering


  mieBeta = 3.996e-6, -- 1/m, clear sky baseline
  mieAlbedo = 0.9,    -- single scatter albedo
  mieH = 1200.0,      -- m, scale height
  mieG = 0.80,        -- Henyey-Greenstein asymmetry

  -- ozone absorption


  ozoneBeta = vec3(0.650e-6, 1.881e-6, 0.085e-6), -- 1/m
  ozoneCenter = 25000.0,                          -- m, altitude of peak density
  ozoneWidth = 15000.0,                           -- m, half-width

  -- planet geom


  earthRadius = 6360000.0,      -- m
  atmosphereRadius = 6460000.0, -- m, at 100km

  -- solar irradiance at top of atmosphere
  -- rgb integrated from 5778k blackbody
  -- normalised so zenith noon after transmittance is approx 1.0


  solarIrradiance = rgb(1.000, 0.964, 0.898)


}
