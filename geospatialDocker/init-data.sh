#!/bin/bash
set -e

echo "Initializing sample data in PostGIS..."

# Wait for PostGIS to be ready
until pg_isready -h postgis -p 5432 -U gisuser; do
  echo "1. Waiting for PostGIS to start..."
  sleep 2
done

# Download sample Natural Earth data (countries)
echo "2. Downloading Natural Earth data..."
mkdir -p /data/world
cd /data/world
wget -q https://naturalearth.s3.amazonaws.com/110m_cultural/ne_110m_admin_0_countries.zip
unzip -o ne_110m_admin_0_countries.zip

# Load into PostGIS
echo "3. Importing shapefile into PostGIS..."
ogr2ogr -f "PostgreSQL" PG:"host=postgis port=5432 dbname=gisdb user=gisuser password=gispwd" \
  ne_110m_admin_0_countries.shp -nln countries -nlt MULTIPOLYGON -overwrite

cd -

# Wait for PostGIS to be ready
until psql -h postgis -U gisuser -d gisdb -c "SELECT 1;" > /dev/null 2>&1; do
  echo "4. Waiting for PostGIS to be ready..."
  sleep 2
done

# Loop through all .shp files in /data/shp
for SHAPEFILE in /data/shp/*.shp; do
  echo "5. Loading local data into PostGIS..."
  if [[ -f "$SHAPEFILE" ]]; then
    BASENAME=$(basename "$SHAPEFILE" .shp)
    echo "...Loading $BASENAME into PostGIS..."
    ogr2ogr -f "PostgreSQL" PG:"host=postgis port=5432 user=gisuser dbname=gisdb password=gispwd" "$SHAPEFILE" -nln "$BASENAME" -overwrite -progress -lco GEOMETRY_NAME=geom -lco FID=osm_id
  else
    echo "No shapefiles found in /shapefiles"
    exit 1
  fi
done

echo "All shapefiles loaded successfully!"

echo "✅ Data import complete!"
