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

## Convert to a game heightmap

The repository now includes a GDAL-based preparation script. Install GDAL command-line tools, then run:

```bash
python tools/geodata/prepare_dem_heightmap.py data/dem/copernicus-glo30/YOUR_TILE.tif
```

It creates a normalized 16-bit PNG and a matching JSON metadata file in a `prepared/` folder. The JSON stores the source elevation minimum/maximum, geotransform, coordinate system, and the formula needed to restore heights in metres. Use `--size 257`, `513` (default), or another supported grid size to control terrain detail.

The current converter resamples the whole one-degree source tile. For production regions, add clipping/reprojection to a local metric CRS and seam-aware neighboring-tile borders before generating final LOD chunks.

Do not use one giant global terrain mesh or load every raster into RAM.
