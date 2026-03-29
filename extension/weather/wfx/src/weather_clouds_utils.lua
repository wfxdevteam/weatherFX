---@alias CloudInfo { pos: vec3, cloud: ac.SkyCloudV2, flatCloud: ac.SkyCloudV2?, cloudAdded: boolean, flatCloudAdded: boolean, size: vec2, procMap: vec2, procScale: vec2, opacity: number, weatherThreshold: number, distK: number }
---@alias CloudsLayerDef { cellDistance: integer, cellSize: number, heightMin: number, heightMax: number, cloudsPerCell: integer, sortOffset: number, horizonFix: number, cloudFactory: (fun(pos: vec3): ac.SkyCloudV2), flatCloudFactory: (fun(c: ac.SkyCloudV2): ac.SkyCloudV2), lightPollution: boolean, castShadow: boolean }
---@alias CloudsUpdateContext { cameraPos: vec3, windDir: vec2, windSpeed: number, cloudsCount: number, cameraMoved: boolean, cellDistance: number, windDelta: number, shapeShiftingDelta: number, cloudsFade: number }

-- flatCloudFactory = function (c) return createCloud(CloudTypes.Bottom, c) end
-- TODO: CloudInfo.size is not needed?