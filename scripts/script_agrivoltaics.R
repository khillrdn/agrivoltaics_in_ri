
#==============================================================================
# PROJECT: Rhode Island Agrivoltaic Land Suitability Analysis
# AUTHOR: Kayleigh Hill
# COURSE: Yale Environmental Data Science Capstone 2026
# PURPOSE: Multi-Criteria Decision Analysis (MCDA) to identify optimal 
#          towns for solar-agriculture co-location.
# DATA SOURCES: RIGIS (2020 Land Use, 2011 LiDAR, 1997 Municipality Lines)
#==============================================================================

#========================= SET UP & REPRODUCIBILITY ===========================

library(tidyr)
library(tidyverse)
library(tidyterra)
library(sf)
library(terra)
library(scales)
library(ggrepel) # Required for non-overlapping labels in bubble plots

# setwd("/Users/brendanelba/Downloads/r_kay")

# Define color palette for consistency across visuals
green_palette <- colorRampPalette(c("#f7fcf9", "#00441b"))(4)

#================================ DOWNLOAD DATA ===============================

# DATA SOURCES:
# 1. ri_town_lines: RIGIS (1997) - Municipal boundaries
# 2. ri_land_cover: RIGIS (2020) - LULC Vector data
# 3. ri_elevation_dem: USGS (2011) - 1m LiDar Digital Elevation Models
# All data projected to NAD83 / Rhode Island (ftUS) - EPSG:3438

setwd("/Users/brendanelba/Downloads/r_kay")

ri_town_lines <- st_read("ri_town_lines_1997/ri_town_lines_1997.shp")

ri_land_cover <- st_read("land_cover_use_2020/land_cover_use_2020.shp") %>% 
  filter(Descr_2020 %in% c("Idle Agriculture (abandoned fields and orchards)", 
                           "Cropland (tillable)", 
                           "Pasture (agricultural not suitable for tillage)", 
                           "Orchards, Groves, Nurseries"))

ri_elevation_dem <- list.files("ri_elevation_dem", pattern = "\\.img$", recursive = TRUE, full.names = TRUE)

#========================= DATA EXPLORATION & CLEANING ========================

## Viz 1: Rhode Island Land Use by Town

    # First look at the four agriculture land cover types of interest broken out by town and                  plotted on the Rhode Island state map

(ri_land_use_by_town_map <- ggplot() +
    # Add municipality boundaries with black outlines
    geom_sf(data = ri_town_lines, fill = NA, color = "black", linewidth = 0.5) +
    geom_sf(data = ri_land_cover, aes(fill = Descr_2020), color = NA) +
    theme_minimal() +
    labs(
      title = "Ag Land Use Cover in Rhode Island Towns", 
      caption = "RIGIS Vector Data"))

# Now identify which towns have the most agricultural land
  # First cut the land cover polygons by the municipality boundaries
intersections <- st_intersection(ri_land_cover, ri_town_lines)
  # Now calculate the area of the new intersected pieces - farmland between town lines
intersections$area_sqm <- st_area(intersections)

# Create a summary plot
town_farm_land_use <- intersections %>%
  st_drop_geometry() %>% # Convert to a standard table for faster math
  group_by(NAME) %>%
  summarize(total_acres = sum(Acres_2020, na.rm = TRUE)) %>%
  arrange(desc(total_acres))

# Viz 2: A bar chart of total farmland acreage by municipality
ggplot(town_farm_land_use, aes(x = reorder(NAME, total_acres), y = total_acres)) +
  geom_col(fill = "darkgreen", color = "white") +
  coord_flip() +  # Flip the chart to make municipality names readable
  labs(
    title = "Distribution of Agricultural Land by RI Municipality (2020)",
    subtitle = "Aggregated acreage of tillable, pasture, and idle agricultural land",
    x = "Municipality",
    y = "Total Area (Acres)"
  ) +
  theme_minimal()

# Now join the summary back to the spatial town data
muni_map_data <- ri_town_lines %>%
  left_join(town_farm_land_use, by = "NAME") %>%
  st_transform(3438) #EPSG code - transforming from m^2 to US feet

## Viz 3: Map the spatial concentration of agricultural land in Rhode Island Towns
ag_land_concentration <- ggplot(data = muni_map_data) +
  geom_sf(aes(fill = total_acres), color = "black", size = 0.2
)+
  scale_fill_stepsn(
    colors = c("#f7fcf5", "#00441b"),
    na.value = "grey90", # Color for missing data
    n.breaks = 5, # creating 5 bins
    name = "Agricultural Land (Acres)"
) +
  theme_minimal() +
  labs(title = "Concentration of Agricultural Land by RI Towns",
       subtitle = "Aggregated from 2020 Land Cover Use Data",
       caption = "Source: RIGIS / Land Cover Analysis"
) +
  theme(
    plot.title = element_text(size = 18, face = "bold"), 
    axis.text = element_blank(), 
    axis.title = element_blank(),
    panel.grid = element_blank()
)
print(ag_land_concentration)

## From viz 2 & 3, identify the 7 towns that have over 2000 total acres of farmland

# Agricultural Composition of Top 7 Towns
  # Filter the main data for these 7 towns and group by both Name and Type
muni_type_breakdown <- intersections %>%
  st_drop_geometry() %>%
  filter(NAME %in% target_towns) %>%
  group_by(NAME, Descr_2020) %>%
  summarize(Type_Acres = sum(Acres_2020, na.rm = TRUE), .groups = "drop")

# Change labels for clarity
my_labels <- c("Cropland (tillable)" = "Cropland",
               "Pasture (agricultural not suitable for tillage)" = "Pasture",
               "Orchards, Groves, Nurseries" = "Orchards, Groves, Nurseries",
               "Idle Agriculture (abandoned fields and orchards)" = "Idle Agriculture"
)

# Viz 4: A "normalized" stacked bar chart showing percentage of each type of farmland cover
breakdown_bar_chart <- ggplot(muni_type_breakdown, 
                              aes(x = reorder(NAME, Type_Acres, sum), 
                                  y = Type_Acres, 
                                  fill = Descr_2020)) +
  geom_col(position = "fill", color = "black", linewidth = 0.2) +
  coord_flip() +
  guides(fill = guide_legend(reverse = TRUE)) +
  scale_y_continuous(labels = scales::percent) + # Make axis to 0-100%
  scale_fill_manual(values = green_palette, name = "Land Use Type", labels = my_labels) +
  labs(title = "Relative Agricultural Composition of Top 7 RI Towns",
       subtitle = "Percentage of farmland type per town",
       x = "Town", y = "Proportion of Total Acreage") +
  theme_minimal() +
  theme(legend.position = "bottom")

print(breakdown_bar_chart)

#======================= Elevation Data Pre-Upload Work =======================

## Breaking out what raster elevation data to download. Entire state elevation data is too large a file for this capstone

# To manage processing time, the project will breakout the 7 priority towns
target_towns <- intersections %>%
    filter(NAME %in% c("SOUTH KINGSTOWN", "LITTLE COMPTON", "EXETER", "RICHMOND", "PORTSMOUTH", "NORTH KINGSTOWN", "MIDDLETOWN"))

# Load the Tile Index ust downloaded
tiles <- st_read("tile_index/USGS_2011_LiDAR_index.shp")

# Find which tiles overlap with priority farmland
  # Creates a list of just the tiles actually needed
needed_tiles <- tiles[target_towns, ]

# See the list of IDs
print(needed_tiles$ID) # Or whichever column has the filename

# Now that the IDs are known, the elevation raster data can be downloaded 
  # Pull in the list of all the unzipped DEM files (see the "Download Data" section)

write_csv(needed_tiles, "elevation_raster_tiles_ag_land")
#================= Create Virtual Raster (VRT) Workflow ======================

# Create a Virtual Raster for performance
  # This treats all 106 files as one single object called 'vrt_dem'
vrt_dem <- vrt(ri_elevation_dem, "ri_farmland_dem.vrt", overwrite = TRUE)

# Check it out
print(vrt_dem)
plot(vrt_dem, main = "Rhode Island Elevation (VRT)")

#=============================== Calculate Slope =============================

# Calculate slope in degrees
# 'filename' tells R to write the result to your disk instead of keeping it in RAM
ri_slope <- terrain(vrt_dem, v = "slope", unit = "degrees", 
                    filename = "ri_slope_output.tif", overwrite = TRUE)

plot(ri_slope, main = "Calculated Slope (Degrees)")

#=================== Define & Classify Slope Suitability =====================

# Slope (Degrees)	| Suitability Score	| Description
# 0 – 3°	                4	            Ideal / Flat
# 3 – 8°	                3	            Good
# 8 – 15°	                2	            Marginal (Higher Costs)
# > 15°	                  1	            Unsuitable / High Erosion


# Define the scoring matrix: [from, to, new_value]
m <- c(0, 3, 4,
       3, 8, 3,
       8, 15, 2,
       15, 90, 1)

reclass_matrix <- matrix(m, ncol=3, byrow=TRUE)

# Apply the scores
slope_scores <- classify(ri_slope, reclass_matrix, filename = "slope_suitability.tif")

write_csv(slope_scores, "ranked_slope_suitability")
#==================== Conver Land Cover to SpatRaster =====================

# Convert the intersections to a terra SpatVector
  # Filter for the top 7 Towns
farmland_vect <- vect(target_towns)

# Combine all small farm polygons into 1 shape per town - only want to look at the seven towns, not the individual plots of farmland
farmland_town_clean <- aggregate(farmland_vect, by = "NAME")

# Force-project the vector to match the raster exactly
farmland_vect_projected <- project(farmland_town_clean, crs(slope_scores))

#=============================== Mask by Ag Land =============================

# Keeping the raster values only where the polygons are 
  # (aka masking slope data to agricultural boundaries only)
slope_cropped <- crop(slope_scores, farmland_vect_projected)
farmland_slope_masked <- mask(slope_cropped, farmland_vect_projected)

# Plot the farmland 
plot(farmland_slope_masked, main = "Masked Suitability Scores for the Top 7 Towns (Farmland Only)")

# Calculating the mean suitability score for each town
town_results <- zonal(farmland_slope_masked, farmland_vect_projected["NAME"], fun = "mean", na.rm = TRUE)

# CHECK: If R dropped the names, then manually add them back
if (ncol(town_results) == 1) {
  # Create a clean data frame using the names from our aggregated vector
  town_results <- data.frame(
    town_name = farmland_vect_projected$NAME,
    slope_score = town_results[,1]
  )
} else {
  # If R kept the names, just rename the columns
colnames(town_results) <- c("town_name", "slope_score")
}

# Sort so the best town is at the top
town_results <- town_results %>% 
  arrange(desc(slope_score))

print(town_results)

write_csv(town_results, "slope_scores")

#=========================== MULTI-CRITERIA ANALYSIS =========================

## We are looking at existing agriculture land that could have agrivoltaics implemented. The goal is to find the cheapest, easiest land to build on without upsetting active farmers or changing existing crops.

#====================== Calculate Mean Slope Suitability =====================

## CRITERIA 1: Slope Suitability (35%)

# Calculate Mean Slope Suitability per Town
# Join the math back to the shapes for a final map
final_suitability_map <- merge(target_towns, town_results, by.x = "NAME", by.y = "town_name")

# Viz 5: Plot Town Slope Suitability for Agrivoltaics
slope_suitability_plot <- ggplot(final_suitability_map) +
  geom_sf(aes(fill = slope_score)) +
  scale_fill_viridis_c(option = "plasma", name = "Feasibility\n(1-4)") +
  labs(title = "Agrivoltaic Suitability on RI Farmland",
       subtitle = "Analysis of RI Towns with the Most Farmland",
       caption = "Data: RIGIS 2011 LiDAR & 2020 Land Use") +
  theme_minimal()

print(slope_suitability_plot)

#===================== Scoring Land Used for Agriculture =====================

## CRITERIA 2: Land Use Type (20% Weight)

    # Idle Agriculture (Score 4): Best. No active crops to displace; often clear of large trees.
    # Pasture (Score 3): Great. Flat, cleared, and low-impact to the soil to install racking.
    # Cropland (Score 2): Marginal. High value for food; installation disrupts active tillable soil.
    # Orchards/Nurseries (Score 1): Worst. Removing trees is expensive and significantly changes the          land use.

# Create the scoring "lookup" table
land_use_scores <- data.frame(
  Descr_2020 = c(
    "Idle Agriculture (abandoned fields and orchards)", # Highest: Low conflict
    "Cropland (tillable)",                              # Moderate: High soil value and tillable
    "Pasture (agricultural not suitable for tillage)",  # High: Perfect for sheep/grazing
    "Orchards, Groves, Nurseries"),                     # Lowest: High clearing costs/permanent crops
  cover_score = c(4, 3, 2, 1)
)

# Joining the scores to the 'intersections' data
land_use_scores_jnd <- intersections %>%
  left_join(land_use_scores, by = "Descr_2020")%>%
  filter(NAME %in% c("SOUTH KINGSTOWN", "LITTLE COMPTON", "EXETER", "RICHMOND", "PORTSMOUTH", "NORTH KINGSTOWN", "MIDDLETOWN"))

# Calculate the area-weighted mean of agricultural land use for each town
avg_land_use_score <- land_use_scores_jnd %>% 
  st_drop_geometry() %>%
  group_by(NAME) %>%
  # Multiply score by acreage, then divide by total town acreage
  summarize(avg_land_use_score = sum(cover_score * Acres_2020) / sum(Acres_2020)) %>%
  arrange(desc(avg_land_use_score))

print(avg_land_use_score)

write_csv(avg_land_use_score, "land_use_suitability_scores")

#======================= Total Available Farmland Score =======================

## CRITERIA 3: Plot Efficiency & Capacity (45% Weight)
  # Thresholds based on industry standards for Utility vs. Community Scale solar

# 1. Utility Ratio (60%): Reward plots over >25 acres size.
    # > 70 ratio = 4 points (Utility Scale)
    # 66-69 ratio = 3 points (Community Scale)
    # 62-65 ratio = 2 points (Standard)
    # >61 ratio = 1 points (Marginal)
# 2. Capacity Score (40%): Reward the total volume.
    # > 3,500 acres = 4 points
    # 3,499–2,500 acres = 3 points
    # 2,199–2,499 acres = 2 points
    # < 2,100 acres = 1 point

# Utility Scale Analysis: Plots > 25 Acres

town_viability_ranks <- intersections %>%
  filter(Acres_2020 >= 2.0) %>%
  filter(NAME %in% c("SOUTH KINGSTOWN", "LITTLE COMPTON", "EXETER", 
                     "RICHMOND", "PORTSMOUTH", "NORTH KINGSTOWN", "MIDDLETOWN")) %>%
  st_drop_geometry() %>%
  group_by(NAME) %>%
  summarize(
    total_viable_acreage = sum(Acres_2020, na.rm = TRUE),
    avg_viable_plot_size = mean(Acres_2020, na.rm = TRUE),
    
    # Calculate how much acreage comes from plots > 25 acres
    utility_scale_acreage = sum(Acres_2020[Acres_2020 > 25], na.rm = TRUE),
    
    # Create the Utility Ratio (AKA what % of town ag land is > 25 acre plots?)
    utility_ratio = (utility_scale_acreage / total_viable_acreage) * 100
  ) %>%
  mutate(
    # Efficiency Score taken from Utility Ratio
    # This should reward towns where the majority of land is in large, efficient blocks
    size_score = case_when(
      utility_ratio >= 70 ~ 4, # Over 70% the town's farmland is Utility-Scale
      utility_ratio >= 66 ~ 3, 
      utility_ratio >= 62 ~ 2,
      TRUE                ~ 1
    ),
    
    # 2. Capacity Score (Total Volume)
    capacity_score = case_when(
      total_viable_acreage >= 3500 ~ 4,
      total_viable_acreage >= 2500 ~ 3,
      total_viable_acreage >= 2100  ~ 2,
      TRUE                         ~ 1
    ),
    
    # Finally, the Combined Viability (60% Ratio Efficiency / 40% Total Capacity)
    combined_viability_score = (size_score * 0.6) + (capacity_score * 0.4)
  ) %>% 
  arrange(desc(combined_viability_score))

print(town_viability_ranks)

write_csv(town_viability_ranks, "farmland_availability_scores")

#====================== FINAL WEIGHTED OVERLAY ANALYSIS =====================

## If this analysis were to be implemented on a larger research scale, instead of a weighted overlay analysis, it would be recommended to implement an Analytic Hierarchy Process (AHP) which would move the analysis from the current "best guess" weights to a mathematically validated Priority Vector.

# Model Logic: Land Viability (45%) + Slope (35%) + Land Cover (20%)

# Joining it all together
final_capstone_results <- town_results %>%
  inner_join(avg_land_use_score, by = "NAME") %>%
  inner_join(town_viability_ranks, by = "NAME") %>%

  # The final weighted index
  mutate(Total_Suitability = (slope_score * 0.35) + 
                             (combined_viability_score * 0.45) + 
                             (avg_land_use_score * 0.2)) %>%
  arrange(desc(Total_Suitability))

# Assign Final Rank
final_capstone_results$final_rank <- 1:nrow(final_capstone_results)

# Print the results to verify
print(final_capstone_results %>% 
        select(final_rank, NAME, Total_Suitability, slope_score, combined_viability_score, avg_land_use_score))

write_csv(final_capstone_results, "final_capstone_results_tbl.csv")

#========================= VISUALIZING THE RESULTS ===========================

## VIZ A: Efficiency vs. Capacity Bubble Plot 
      # Create a bubble plot to show the technical constraints

# Calculate averages for the quadrant cross hairs
ggplot(final_capstone_results, aes(x = avg_viable_plot_size, y = total_viable_acreage)) +
  geom_vline(xintercept = mean(final_capstone_results$avg_viable_plot_size), linetype = "dashed", color = "grey70") +
  geom_hline(yintercept = mean(final_capstone_results$total_viable_acreage), linetype = "dashed", color = "grey70") +
  
  # Point size is tied to the NEW combined viability (Efficiency + Capacity)
  geom_point(aes(size = avg_land_use_score, fill = slope_score),
             shape = 21, color = "black", alpha = 0.85) +
  
  geom_text_repel(aes(label = NAME), fontface = "bold", size = 2) +
  
  scale_size_continuous(range = c(5, 15), name = "Ag Land Suitability") + # Bubble Size: Slope suitability (How flat is it?).
  scale_fill_gradient(low = "#f7fcf5", high = "#00441b", name = "Slope Suitability") +
  scale_y_continuous(labels = scales::comma) +
  
  labs(title = "Trade-offs in Rhode Island Agrivoltaic Suitability",
       subtitle = "Evaluating the Balance of Slope Grade, Parcel Scale, Town Capacity, and Agricultural Land Sensitivity",
       x = "Ratio of Plots >25 acres (Utility Scale)", # X-Axis: Efficiency (Are the plots big enough to make construction costs worth it?).
       y = "Total Farmland Acres (Development Capacity)") + # Y-Axis: Total Capacity (How much solar can we build?).
  theme_minimal() +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey95"),
    legend.title = element_text(size = 9, face = "bold"),
    legend.background = element_rect(fill = "white", color = NA),
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 10, color = "grey40")
  )
      
#Interpretation: This highlights that Middletown has large agricultural land plots - meaning it has greater power capabilities per plot and less installation costs, versus South Kingstown which has a higher concentration of total agricultural land but smaller plot size and therefor higher installation costs.

## VIZ B: "Final Suitability" Choropleth Map

# Join results back to spatial data
final_map_data <- ri_town_lines %>%
  inner_join(final_capstone_results, by = "NAME")

write_csv(final_map_data, "final_suitability_data")

ggplot() +
  geom_sf(data = ri_town_lines, fill = "grey85", color = "white", linewidth = 0.1) + # base map
  
  geom_sf(data = final_map_data, aes(fill = Total_Suitability), color = "black", linewidth = 0.3) + # suitability data on top 7 towns
  
  scale_fill_gradient(low = "#f7fcf5", high = "#00441b", 
                      name = "Suitability Index", 
                      na.value = "grey95") +
  
  labs(title = "Richmond and Little Compton Show \nGreatest Suitability fo Agrivoltaics",
       subtitle = "A Multi-Criteria Evaluation of Top Agricultural Hubs Based on Topography and Land-Use",
       caption = "Analysis based on 2011 LiDAR and 2020 Land Use Data") +
  theme_void() +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 10, color = "grey30"),
        plot.margin = margin(10, 10, 10, 10)
  )

## VIZ C: Scoring Composition Stacked Bar: 
      # Stacked bar chart showing how much each town's score was influenced by each factor (slope grade, plot size and total acreage of ag land per town, and land cover type). This is a way to defend the weighting choices. 

# Reshape data for plotting
plot_breakdown <- final_capstone_results %>%
  mutate(Slope_Component = slope_score * 0.35,
         Viability_Component = combined_viability_score * 0.45,
         Cover_Component = avg_land_use_score * 0.2) %>%
  select(NAME, Slope_Component, Viability_Component, Cover_Component) %>%
  pivot_longer(cols = -NAME, names_to = "Metric", values_to = "Score")

ggplot(plot_breakdown, aes(x = reorder(NAME, Score, sum), y = Score, fill = Metric)) +
  geom_col(color = "black", linewidth = 0.2) +
  coord_flip() +
  scale_fill_manual(values = green_palette,
                    labels = c("Farmland Type (20%)", "Slope (35%)", "Viability (45%)"),
                    name = "Weighted Components") +
  labs(title = "Composition of Suitability Scores",
       subtitle = "Multi-criteria analysis of topography, land availability, and existing agricultural type",
       x = "Town", y = "Total Weighted Score (out of 4)") +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "grey30"),
    axis.title = element_text(face = "bold"),
    legend.title = element_text(face = "bold")
)

#=============================================================================
# END OF SCRIPT
#=============================================================================
