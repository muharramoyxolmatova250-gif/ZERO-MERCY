# Generated Earth data

Run from the repository root:

```bash
python tools/geodata/download_natural_earth.py --scale 110m
```

This creates `world-110m.geojson` in this folder. Use `--scale 50m` for the medium-detail dataset. The downloaded GeoJSON files are intentionally not committed because they are reproducible generated inputs.

Natural Earth data is public domain. Source and terms:
- https://www.naturalearthdata.com/downloads/
- https://www.naturalearthdata.com/about/terms-of-use/
