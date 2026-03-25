# The Technical Potential of Agrivoltaics in Rhode Island
Yale Environmental Data Science Certificate | Capstone 2025-26

## The Issue: 
Rhode Island faces an acute challenge, with some of the nation's highest farmland costs ($20,000 per acre, USDA NASS) and a projected 13.7% decline in available farmland by 2040 (American Farmland Trust). At the same time, the state has set aggressive clean energy goals, legally bound to producing 100% renewable electricity by 2030 (Executive Order 20-01). 

Agrivoltaics (AV), a form of dual-use farming, integrates solar energy generation and food production on the same land, maximizing land use and creating multiple revenue streams for farmers.

AV offers a potential path to enhance food security, preserve farmland, and increase clean energy production. The feasibility of expanding agrivoltaics in RI warrants exploration as a mechanism to help secure the state's energy and food future.

## Project Question
What is the technical potential of agrivoltaics in Rhode Island as a dual-use strategy for renewable energy and farmland preservation? This investigation aims to provide a method of diversifying the state's energy production while providing farmers with financial incentives to protect prime agricultural land from commercial, industrial, urban, and suburban development.

    1. What is the total potential of available agricultural land in each municipality?
    2. What are the top seven towns with the greatest agricultural capacity and determine which have the most suitable             agricultural land cover and slope grade for solar and agricultural dual use?
    4. Which town holds the greatest potential?

## Data Sources
All data pulled from Rhode Island GIS (https://www.rigis.org/)
    - LiDAR-Derived Slope Data (2011): Raster 1-M elevation data 
    - Land Use/Cover Data (2020): Vector dataset. Filtering for four compatible agriculture types (idle ag, cropland, pasture, and orchard/vineyard)
    - Municipality Boundaries (1997): Vector data determining town lines

## Methodology: Multi-Criteria Decision Analysis (MCDA)
The analysis utilizes a geospatial MCDA framework to identify optimal co-location zones

## Process
- Data Loading
    - Download vector data: town boundaries & land use cover, filtering for 4 ag categories
    - Identify the top 7 high-capacity ag land towns
    - Catalog 1-meter resolution LiDAR-derived DEM data for top 7 towns - filtering for ag land only (to reduce the size of the dataset to ensure it can be downloaded
- Spatial Pre-Processing 
    - Clip ag land vectors to town boundaries to calculate acreage
    - Create virtual raster (VRT) to treat the 106 individual LiDAR files as one elevation layer
- Slope & Suitablity Modeling
    - Calculate topographic slope in degrees from LiDAR VRT
    - Discretize slope into a 1-4 suitability scale (flat to unsuitable)
    - Perform zonal statistics to find the mean slope score (engineering/installation feasibility) for each municipality
    - Convert land use data to SpatRaster and then mask slope data to ag boundaries (both need to be in raster form to perform this)
- Multi-Criteria Decision Analysis
    - Using a weighted overlay, the final suitability index is created. Three models are weighted on a scale of 1-4 with 1 being most suitable and 4 being unsuitable.
       1. Slope feasibility (35%) - indicates engineering costs of installation
       2. Land use reality (20%) - ag land cover types ranked based on ease of implementing solar while maintaining ag yield
       3. Operational viability: looking at average plot size per town and total ag acreage per town. Weighted 60/40 respectively. Area-weighted mean used to determine final town scores.
- Visual Creation
    - Viz A: Strategy Analysis - shows each variable in a bubble map
    - Viz B: Spatial Distribution & Final Suitability Index - choropleth map
    - Viz C: Model Defense - stacked bar chart shows final score breakdown to show criteria that drove town rankings

## Built With
- R in RStudio (packages: tidyverse, tidyterra, sf, terra, scales, & ggrepel)

## Licenses
For Educational Use Only: The contents of this project are for learning and practicing purposes only.

## Contact
Author: Kayleigh Hill | Email: khillrdn@gmail.com

