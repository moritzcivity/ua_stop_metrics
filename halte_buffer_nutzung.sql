WITH bkg_select as(
/* gibt Polygon mit beistimmten ags Wert aus*/
SELECT
bkg.vg250_gem_2017.ags  as ags,
bkg.vg250_gem_2017.geom  as geom,
bkg.vg250_gem_2017.gen  as stadt,
ST_Area((ST_Dump(bkg.vg250_gem_2017.geom)).geom) as area /* Polygon wird aufgesplitet und später aussortiert ( nur polygon mit größter Fläche wird verwendet) damit werden spätere Fehler verhindert*/
FROM  bkg.vg250_gem_2017
WHERE bkg.vg250_gem_2017.ags = '07111000' /* hier ags ändern*/
)
/* wählt Polygon mit größter Fläche aus*/
,bkg_ags as(
 SELECT bkg_select.geom as geom,
 bkg_select.stadt  as stadt
 FROM bkg_select
 WHERE area = (SELECT max(area) from bkg_select)
)

,stops_in_bkg as(
/* gibt vereinigten Buffer der Stops aus, die innerhalb des oben definierten ags-Polygons liegen*/
SELECT  
ST_Union(ST_Buffer(hafas.stops.geom::geography,300)::geometry )as geom
FROM bkg_ags, hafas.stops
WHERE st_within(hafas.stops.geom , bkg_ags.geom) = True 
)

,intersect_ags as(
SELECT  ST_Intersection(urbanatlas.ua2012b.geom, bkg_ags.geom) as geom, 
urbanatlas.ua2012b.item2012 as item2012,
urbanatlas.ua2012b.item2006 as item2006,  
ST_Area(ST_Intersection(urbanatlas.ua2012b.geom::geography, bkg_ags.geom::geography)) as area
FROM urbanatlas.ua2012b, bkg_ags
WHERE /*bkg.vg250_gem_2017.ags = '07111000' hier ags ändern*/
urbanatlas.ua2012b.cities = bkg_ags.stadt /* angeben, um kein intersect mit kopletten Datensatz zu machen*/
AND  ST_IsEmpty ( ST_Intersection(urbanatlas.ua2012b.geom, bkg_ags.geom) ) = FALSE
)

,intersect_buffer as(
SELECT  ST_Intersection(intersect_ags.geom, stops_in_bkg.geom) as geom,
intersect_ags.item2012 as item2012,
intersect_ags.item2006 as item2006,
ST_Area(ST_Intersection(intersect_ags.geom::geography, stops_in_bkg.geom::geography)) as area
FROM intersect_ags, stops_in_bkg
WHERE  ST_IsEmpty ( ST_Intersection(intersect_ags.geom, stops_in_bkg.geom) ) = FALSE
)
 
, buffer2006 as (
SELECT DISTINCT item2006 as item, SUM(area /(SELECT SUM(area) FROM intersect_buffer))*100 as Prozent
FROM intersect_buffer
GROUP BY item2006
)
    
 , buffer2012 as (
SELECT DISTINCT item2012 as item, SUM(area /(SELECT SUM(area) FROM intersect_buffer))*100 as Prozent
FROM intersect_buffer
GROUP BY item2012
)
 
, t2006 as (
SELECT DISTINCT item2006 as item, SUM(area /(SELECT SUM(area) FROM intersect_ags))*100 as Prozent
FROM intersect_ags
GROUP BY item2006
)
    
 , t2012 as (
SELECT DISTINCT item2012 as item, SUM(area /(SELECT SUM(area) FROM intersect_ags))*100 as Prozent
FROM intersect_ags
GROUP BY item2012
)
    
/*SELECT t2012.item as nutz12, t2012.Prozent as prozent12, t2006.item as nutz06, t2006.Prozent as prozent06, (t2012.Prozent - t2006.Prozent) as aenderung06_12
FROM t2006 FULL OUTER JOIN t2012
ON t2006.item = t2012.item
ORDER BY t2012.Prozent DESC; */

SELECT buffer2012.item as buffer_nutz12, buffer2012.Prozent as buffer_prozent12, 
buffer2006.item as buffer_nutz06, buffer2006.Prozent as buffer_prozent06, 
(buffer2012.Prozent - buffer2006.Prozent) as buffer_aenderung06_12,
t2012.item as gesamt_nutz12, t2012.Prozent as gesamt_prozent12,
t2006.item as gesamt_nutz06, t2006.Prozent as gesamt_prozent06,
(t2012.Prozent - t2006.Prozent) as gesamt_aenderung06_12
FROM buffer2006 
FULL OUTER JOIN buffer2012 ON buffer2006.item = buffer2012.item
FULL OUTER JOIN t2012 ON buffer2006.item = t2012.item
FULL OUTER JOIN t2006 ON buffer2006.item = t2006.item
ORDER BY buffer2012.Prozent DESC; 