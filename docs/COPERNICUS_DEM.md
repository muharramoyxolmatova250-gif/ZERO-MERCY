# Copernicus DEM GLO-30 elevation tiles

ZERO MERCY uses the public Copernicus DEM GLO-30 Cloud Optimized GeoTIFF collection as its first high-resolution elevation source.

## Download a small test area

The bounding box order is west, south, east, north:

```bash
python tools/geodata/download_copernicus_dem.py --bbox 72.0 40.0 73.5 41.0
```

This example covers a small area near Andijan in eastern Uzbekistan. It downloads 1×1 degree tiles intersecting the requested bounds into `data/dem/copernicus-glo30/`. You can choose another region, but do not request the whole planet in one run: the dataset is very large.

## Data details and limitations

- GLO-30 is a Digital Surface Model (DSM), so vegetation and buildings may contribute to elevations; it is not a bare-earth terrain model.
- The AWS-hosted GLO-30 Public instance has a small number of unreleased tiles. The script reports missing tiles rather than pretending global coverage is complete.
- Ocean tiles are not supplied; the ocean surface should be generated separately at sea level.
- Source and access details: https://registry.opendata.aws/copernicus-dem/
- AWS public bucket: https://copernicus-dem-30m.s3.eu-central-1.amazonaws.com/
- Official Copernicus DEM collection and licence: https://dataspace.copernicus.eu/explore-data/data-collections/copernicus-contributing-missions/collections-description/COP-DEM

Review the current licence and attribution requirements before redistributing source tiles or derived products. Cite Copernicus DEM as required by its licence.

## Convert to game terrain

The downloaded files are source rasters, not ready-made Godot heightmaps. The next processing step should use GDAL to:
1. Clip each source COG to a game region.
2. Reproject to a suitable local metric CRS for that region.
3. Resample to a controlled grid size for the target LOD.
4. Export a 16-bit heightmap plus metadata (minimum/maximum elevation, bounds, scale).
5. Build terrain mesh/heightfield chunks and stream them by region.

Do not use one giant global terrain mesh or load every raster into RAM.
