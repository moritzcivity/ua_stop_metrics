/* this query calculates the percental landuse (data from urbanatlas) for the stops cover (given by a certain buffer radius) of a certain city (ags).
Also the percental landuse for the area of the whole city (ags-area) is calculated 

ags for the wanted city can be changed in line 21
bufferradius can be changed in line 35

----NOTE----
to minimize the calculation time the intersection of the ags-polygon with the urbanatlas dataset (line 40) only uses the urbanatlas data for the wanted city
for that there is the WHERE-Clause in line 46. But there will occur an error if the city names in both tables (urbanatlas and ags) aren't the same.
this happens for example  for cities in the Ruhrgebiet.
So if an error occus change line 46 to "WHERE urbanatlas.ua2012b.cities = *name of urbanatlas dataset where the city you want to calculate for*"/

WITH bkg_select as(
/* displays the polygon of an ags-area*/
SELECT
bkg.vg250_gem_2017.ags  as ags,
bkg.vg250_gem_2017.geom  as geom,
bkg.vg250_gem_2017.gen  as stadt,
ST_Area((ST_Dump(bkg.vg250_gem_2017.geom)).geom) as area /* if there are more polygons for one ags they get splitted and later only the polygon with the biggest area is used (else there could be errors)*/
FROM  bkg.vg250_gem_2017
WHERE bkg.vg250_gem_2017.ags = '16053000' /* here the ags for the wanted city can be changed*/
)

,bkg_ags as(
/* chooses polygon with biggest area for further calculations (needed to avoid possible errors)*/
 SELECT bkg_select.geom as geom,
 bkg_select.stadt  as stadt
 FROM bkg_select
 WHERE area = (SELECT max(area) from bkg_select)
)

,stops_in_bkg as(
/* stops within the ags-polygon get buffered (radius variable) and the multiple buffers get united into one polygon*/
SELECT  
ST_Union(ST_Buffer(hafas.stops.geom::geography,300)::geometry )as geom /* in this line the bufferradius can be changed*/
FROM bkg_ags, hafas.stops
WHERE st_within(hafas.stops.geom , bkg_ags.geom) = True 
)

,intersect_ags as(
/* the urbanatlas data get intersected with the ags-polygon and the area for each urbanatlas-polygon gets calculated*/
SELECT  ST_Intersection(urbanatlas.ua2012b.geom, bkg_ags.geom) as geom, 
urbanatlas.ua2012b.item2012 as item2012,
ST_Area(ST_Intersection(urbanatlas.ua2012b.geom::geography, bkg_ags.geom::geography)) as area
FROM urbanatlas.ua2012b, bkg_ags
WHERE urbanatlas.ua2012b.cities = bkg_ags.stadt /* this where clause helps not to intersect with the whole urbanatlas data, so the time for calculation gets lower*/
AND ST_IsEmpty ( ST_Intersection(urbanatlas.ua2012b.geom, bkg_ags.geom) ) = FALSE
)

,intersect_buffer as(
/* the buffer-polygon gets intersected with the polygon from the intersection above (line 40)*/
SELECT  ST_Intersection(intersect_ags.geom, stops_in_bkg.geom) as geom,
intersect_ags.item2012 as item2012,
ST_Area(ST_Intersection(intersect_ags.geom::geography, stops_in_bkg.geom::geography)) as area
FROM intersect_ags, stops_in_bkg
WHERE  ST_IsEmpty ( ST_Intersection(intersect_ags.geom, stops_in_bkg.geom) ) = FALSE
)

    
 , buffer2012 as (
 /* percental area for each landuse class of the stops cover (line 50) gets calculated*/
SELECT DISTINCT item2012 as item, SUM(area /(SELECT SUM(area) FROM intersect_buffer))*100 as Prozent
FROM intersect_buffer
GROUP BY item2012
)
    
 , t2012 as (
 /* percental area for each landuse class of the ags-area (line 40) gets calculated*/
SELECT DISTINCT item2012 as item, SUM(area /(SELECT SUM(area) FROM intersect_ags))*100 as Prozent
FROM intersect_ags
GROUP BY item2012
)

SELECT DISTINCT buffer2012.item as haltestellen_nutzung, buffer2012.Prozent as haltestellen_prozent, t2012.item as ags_nutzung, t2012.Prozent as ags_prozent
FROM buffer2012 FULL OUTER JOIN t2012
ON t2012.item = buffer2012.item