library(dplyr)
library(terra)
library(ggplot2)
library(ggpubr)

## NEED TO CHANGE THE SCRIPT TO USE PFAF_ID  

#########################################################################################################
## getting hydrobasin and river data for our study region and mine polygons

MinePolygons <- "../../data/species_occurrence/data/lithium_mines_brazil/lithium_mines_brazil/brazil_lithium_mines_sigmine_MG_lavra.shp"
MinePolygons <- vect(MinePolygons)

Hydrobasins_level_10 <- "../../data/species_occurrence/data/hybas_lake_sa_lev10_v1c/hybas_lake_sa_lev10_v1c.shp"
Hydrobasins_level_10 <- vect(Hydrobasins_level_10)

Hydrobasins_levels_4 <- "../../data/species_occurrence/data/Mining_pilot_hydrobasins_lev04_08/hydrobasins_lev04_08/hybas_lev08_lithium_mines.shp"
Hydrobasins_levels_4 <- vect(Hydrobasins_levels_4)

Hydrobasins_levels_8 <- "../../data/species_occurrence/data/Mining_pilot_hydrobasins_lev04_08/hydrobasins_lev04_08/hybas_lev08_lithium_mines.shp"
Hydrobasins_levels_8 <- vect(Hydrobasins_levels_8)

Rivers <- "../../data/species_occurrence/data/HydroRIVERS_v10_sa_shp/HydroRIVERS_v10_sa_shp/HydroRIVERS_v10_sa.shp"
Rivers <- vect(Rivers)
Rivers_cropped <- crop(Rivers, Hydrobasins_levels_4) 

crs(MinePolygons)
crs(Hydrobasins_level_10)
crs(Rivers)

MinePolygons <- project(MinePolygons, crs(Hydrobasins_level_10))


#########################################################################################################
## data from Sayer et al. 

## Define relevant cropping level
CropLevel <- Hydrobasins_levels_4

Sayer_FW <- list.files("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/")
Sayer_FW <- Sayer_FW[grepl(".shp", Sayer_FW)]

## load and crop fish files
Sayer_FW_fishes_NonLC <- vect("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/FW_Fishes_Published_NonLC.shp")
crs(Sayer_FW_fishes_NonLC)
Sayer_FW_fishes_NonLC_cropped <- crop(Sayer_FW_fishes_NonLC, CropLevel) 
# plot(Sayer_FW_fishes_NonLC_cropped, "SCI_NAME")
# Sayer_FW_fishes_NonLC_cropped$SCI_NAME ## only 2 species that are non LC

Sayer_FW_fishes_LC1 <- vect("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/FW_Fishes_Published_LC_1.shp")
Sayer_FW_fishes_LC2 <- vect("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/FW_Fishes_Published_LC_2.shp")
Sayer_FW_fishes_LC1_cropped <- crop(Sayer_FW_fishes_LC1, CropLevel) 
Sayer_FW_fishes_LC2_cropped <- crop(Sayer_FW_fishes_LC2, CropLevel) 

## load and crop decapods files
Sayer_FW_decapods <- vect("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/FW_Decapods_All.shp")
crs(Sayer_FW_decapods)
Sayer_FW_decapods_cropped <- crop(Sayer_FW_decapods, CropLevel) 

## load and crop odonates files
Sayer_FW_odonates <- vect("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/FW_Odonates_All.shp")
crs(Sayer_FW_odonates)
Sayer_FW_odonates_cropped <- crop(Sayer_FW_odonates, CropLevel) 

## load and crop amphibian files -- no species intersecting - we will not consider
Sayer_FW_amphibians <- vect("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/Tetrapods_Amphibians_Thr.shp")
crs(Sayer_FW_amphibians)
Sayer_FW_amphibians_cropped <- crop(Sayer_FW_amphibians, CropLevel) 
rm(Sayer_FW_amphibians_cropped, Sayer_FW_amphibians)

## load and crop bird files
Sayer_FW_birds <- vect("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/Tetrapods_Birds_Thr.shp")
crs(Sayer_FW_birds)
Sayer_FW_birds_cropped <- crop(Sayer_FW_birds, CropLevel) 

## load and crop mammal files
Sayer_FW_mammals <- vect("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/Tetrapods_Mammals_Thr.shp")
crs(Sayer_FW_mammals)
Sayer_FW_mammals_cropped <- crop(Sayer_FW_mammals, CropLevel) 

## load and crop reptile files -- no species intersecting - we will not consider
Sayer_FW_reptiles <- vect("../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/4_Spatial Data/Tetrapods_Reptiles_Thr.shp")
crs(Sayer_FW_reptiles)
Sayer_FW_reptiles_cropped <- crop(Sayer_FW_reptiles, CropLevel) 
rm(Sayer_FW_reptiles, Sayer_FW_reptiles_cropped)

#########################################################################################################
## putting data together
Fish_Sayer_data <- as.data.frame(Sayer_FW_fishes_NonLC_cropped)
Fish_Sayer_data$RL_STATUS <- 'DD'
Fish_Sayer_data <- rbind(Fish_Sayer_data, 
                         as.data.frame(Sayer_FW_fishes_LC1_cropped) %>% 
                           mutate(RL_STATUS='LC'))
Fish_Sayer_data <- rbind(Fish_Sayer_data, 
                         as.data.frame(Sayer_FW_fishes_LC2_cropped) %>% 
                           mutate(RL_STATUS='LC'))
Fish_Sayer_data <- unique(Fish_Sayer_data)
Fish_Sayer_data$Group <- "FW_FISH"
row.names(Fish_Sayer_data) <- c(1:nrow(Fish_Sayer_data))

Decapod_Sayer_data <-  as.data.frame(Sayer_FW_decapods_cropped) %>% 
  select(c(SCI_NAME, PRESENCE, ORIGIN, SEASONAL))
Decapod_Sayer_data$Group <- "FW_DECAPOD"

Odonate_Sayer_data <-  as.data.frame(Sayer_FW_odonates_cropped) %>% 
  select(c(SCI_NAME, PRESENCE, ORIGIN, SEASONAL))
Odonate_Sayer_data$Group <- "FW_ODONATE"

Bird_Sayer_data <-  as.data.frame(Sayer_FW_birds_cropped) %>% 
  select(c(SCI_NAME, PRESENCE, ORIGIN, SEASONAL))
Bird_Sayer_data$Group <- "THR_BIRDS"

Mammal_Sayer_data <-  as.data.frame(Sayer_FW_mammals_cropped) %>% 
  select(c(SCI_NAME, PRESENCE, ORIGIN, SEASONAL))
Mammal_Sayer_data$Group <- "THR_MAMMALS"

## merging shapefiles for fishes (cropped)
all_fish_shp <- rbind(Sayer_FW_fishes_NonLC_cropped, Sayer_FW_fishes_LC1_cropped)
all_fish_shp <- rbind(all_fish_shp, Sayer_FW_fishes_LC2_cropped)
rm(Sayer_FW_fishes_LC1_cropped, Sayer_FW_fishes_LC2_cropped, Sayer_FW_fishes_NonLC_cropped)

## merging shapefiles for fishes
all_fish_shp_global <- rbind(Sayer_FW_fishes_NonLC, Sayer_FW_fishes_LC1)
all_fish_shp_global <- rbind(all_fish_shp_global, Sayer_FW_fishes_LC2)
rm(Sayer_FW_fishes_LC1, Sayer_FW_fishes_LC2, Sayer_FW_fishes_NonLC)

## create df with all considered species
All_species <- rbind(Odonate_Sayer_data,
                     Decapod_Sayer_data, 
                     Fish_Sayer_data[ ,-5],
                     Mammal_Sayer_data,
                     Bird_Sayer_data)


#########################################################################################################
## plotting species richness
## converting to rasters (for each species, and obtain a raster stack of presence) -- for fish
Rasterize_function <- function(Shp, Resolution, Data){
  
  RasterStack <- rast()
  ras <- rast(ext(Shp), 
              resolution = Resolution, 
              crs = crs(Shp))
  
  for (i in 1:nrow(Data)){
    
    r_poly <- rasterize(Shp[Shp$SCI_NAME==Data$SCI_NAME[i]],
                        ras,
                        "PRESENCE")
    r_poly[r_poly>1] <- 1
    names(r_poly) <- Data$SCI_NAME[i]
    if(!all(is.na(values(r_poly)))){
      RasterStack <- c(RasterStack, r_poly)
    }
    print(i)
  }
  return(RasterStack)
}

## fish
RasterStackFish <- Rasterize_function(Shp = all_fish_shp, Resolution = 0.001, Data = Fish_Sayer_data)
names(RasterStackFish) %>%  length()

## decapods
RasterStackDecapods <- Rasterize_function(Shp = Sayer_FW_decapods_cropped, Resolution = 0.001, Data = Decapod_Sayer_data)
names(RasterStackDecapods) %>%  length()

## odonates
RasterStackOdonates <- Rasterize_function(Shp = Sayer_FW_odonates_cropped, Resolution = 0.001, Data = Odonate_Sayer_data)
names(RasterStackOdonates) %>%  length()

## birds
RasterStackBirds <- Rasterize_function(Shp = Sayer_FW_birds_cropped, Resolution = 0.001, Data = Bird_Sayer_data)
names(RasterStackBirds) %>%  length()

## mammals
RasterStackMammals <- Rasterize_function(Shp = Sayer_FW_mammals_cropped, Resolution = 0.001, Data = Mammal_Sayer_data)
names(RasterStackMammals) %>%  length()

## plotting species richness
SumRastFish <- sum(RasterStackFish, na.rm=TRUE)
SumRastDecapods <- sum(RasterStackDecapods, na.rm=TRUE)
SumRastOdonates <- sum(RasterStackOdonates, na.rm=TRUE)
SumRastBirds <- sum(RasterStackBirds, na.rm=TRUE)
SumRastMammals <- sum(RasterStackMammals, na.rm=TRUE)

pdf(file = '../../results/species_occurrence/plots/distribution_plots.pdf', width = 7, height = 7)
par(mfrow=c(3,3))

plot(SumRastFish, main='Freshwater fishes (n=20)')
plot(MinePolygons, add=TRUE, col="red")
plot(Rivers_cropped, col='black', add=TRUE, alpha=0.3)

plot(SumRastDecapods, main='Freshwater decapods (n=7)')
plot(MinePolygons, add=TRUE, col="red")
plot(Rivers_cropped, col='black', add=TRUE, alpha=0.3)

plot(SumRastOdonates, main='Freshwater odonates (n=25)')
plot(MinePolygons, add=TRUE, col="red")
plot(Rivers_cropped, col='black', add=TRUE, alpha=0.3)

plot(SumRastBirds, main='Threatened birds (n=4)')
plot(MinePolygons, add=TRUE, col="red")
plot(Rivers_cropped, col='black', add=TRUE, alpha=0.3)

plot(SumRastMammals, main='Threatened mammals (n=9)')
plot(MinePolygons, add=TRUE, col="red")
plot(Rivers_cropped, col='black', add=TRUE, alpha=0.3)

plot(SumRastMammals+
       SumRastBirds+
       SumRastFish+
       SumRastOdonates+
       SumRastDecapods, main='Pseudo richness (n=65)')
plot(MinePolygons, add=TRUE, col="red")
plot(Rivers_cropped, col='black', add=TRUE, alpha=0.3)

dev.off()

#########################################################################################################
## investigating RL threats

Threat_data_odonates <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/2_Threats/FW_Odonates_Threats.csv') 
Threat_data_odonates <- Threat_data_odonates %>% 
  filter(scientificName %in% All_species$SCI_NAME[All_species$Group=='FW_ODONATE'])
  
Threat_data_decapods <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/2_Threats/FW_Decapods_Threats.csv') 
Threat_data_decapods <- Threat_data_decapods %>% 
  filter(scientificName %in% All_species$SCI_NAME[All_species$Group=='FW_DECAPOD'])

Threat_data_mammals <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/2_Threats/Tetrapods_Mammals_Threats.csv') 
Threat_data_mammals <- Threat_data_mammals %>% 
  filter(scientificName %in% All_species$SCI_NAME[All_species$Group=='THR_MAMMALS'])

Threat_data_birds <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/2_Threats/Tetrapods_Birds_Threats.csv') 
Threat_data_birds <- Threat_data_birds %>% 
  filter(scientificName %in% All_species$SCI_NAME[All_species$Group=='THR_BIRDS'])

Threat_data_fish <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/2_Threats/FW_Fishes_Threats.csv') 
Threat_data_fish <- Threat_data_fish %>% 
  filter(friendly_name %in% All_species$SCI_NAME[All_species$Group=='FW_FISH'])

Threats_mammals <- 
Threat_data_mammals %>% 
  group_by(stressName, name, scientificName) %>% 
  summarise(N=n())

Threats_birds <- 
  Threat_data_birds %>% 
  group_by(stressName, name, scientificName) %>% 
  summarise(N=n())

# Threats_mammals %>% 
#   group_by(name) %>% 
#   summarise(N=n())
# 
# Threats_mammals %>% 
#   group_by(stressName) %>% 
#   summarise(N=n())





#########################################################################################################
## investigating RL status
Status_odonates <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/1_Red List Status/FW_Odonates_RL Status.csv') 
Status_odonates <- Status_odonates %>% 
  filter(scientificName %in% All_species$SCI_NAME[All_species$Group=='FW_ODONATE']) %>% 
  mutate(Group='Odonates')
table(Status_odonates$redlistCategory)

Status_decapods <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/1_Red List Status/FW_Decapods_RL Status.csv') 
Status_decapods <- Status_decapods %>% 
  filter(scientificName %in% All_species$SCI_NAME[All_species$Group=='FW_DECAPOD']) %>% 
  mutate(Group='Decapods')
table(Status_decapods$redlistCategory)

Status_fishes <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/1_Red List Status/FW_Fishes_RL Status.csv') 
Status_fishes <- Status_fishes %>% 
  filter(scientificName %in% All_species$SCI_NAME[All_species$Group=='FW_FISH']) %>% 
  mutate(Group='Fishes')
table(Status_fishes$redlistCategory)

Status_birds <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/1_Red List Status/Tetrapods_Birds_RL Status.csv') 
Status_birds <- Status_birds %>% 
  filter(scientificName %in% All_species$SCI_NAME[All_species$Group=='THR_BIRDS']) %>% 
  mutate(Group='Birds')
table(Status_birds$redlistCategory)

Status_mammals <- read.csv('../../data/species_occurrence/IUCN_data_Sayer_et_al/Freshwater_fauna_and_tetrapod_data/1_Red List Status/Tetrapods_Mammals_RL Status.csv') 
Status_mammals <- Status_mammals %>% 
  filter(scientificName %in% All_species$SCI_NAME[All_species$Group=='THR_MAMMALS']) %>% 
  mutate(Group='Mammals')
table(Status_mammals$redlistCategory)

Status <- rbind(Status_odonates[, c('Group', 'scientificName', 'redlistCategory')], 
                Status_decapods[, c('Group', 'scientificName', 'redlistCategory')],
                Status_fishes[, c('Group', 'scientificName', 'redlistCategory')], 
                Status_birds[, c('Group', 'scientificName', 'redlistCategory')], 
                Status_mammals[, c('Group', 'scientificName', 'redlistCategory')])

Status$redlistCategory <- factor(
  Status$redlistCategory,
  levels = rev(c(
    "Least Concern",
    "Near threatened",
    "Vulnerable",
    "Endangered",
    "Critically Endangered",
    "Data Deficient"
  ))
)

RL_Status_plot <- 
ggplot(Status, aes(redlistCategory, fill=redlistCategory)) + 
  geom_bar() + xlab('Red List status') + ylab('Number of species') +
  facet_wrap(~factor(Group, 
                     levels = c("Fishes", "Decapods", "Odonates", "Birds", 
                                'Mammals')), ncol=1, scales = 'free_x') +
  coord_flip() +
  theme_bw()+
  theme(legend.position = 'none') +
  scale_fill_manual( 
                    values = rev(c('palegreen', 'salmon1', 'tomato3', 'darkred', 'darkgrey')))+
  geom_text(
    stat = "count",
    aes(label = after_stat(count)),
    hjust = -0.15, size=3   # move text slightly outside bar
  ) 
                  
ggsave(RL_Status_plot, filename='../../results/species_occurrence/plots/RL_status_plots.pdf', 
       width=5, height=8)


#########################################################################################################
## investigating % range contained within the pilot's region

Range_percent_function <- function(Shp_cropped, Shp_global, Data){
  
  Data$percent_range <- NA
  
  for (i in 1:nrow(Data)){
    region <- 
      Shp_cropped[Shp_cropped$SCI_NAME==Data$SCI_NAME[i]]
    global <- 
      Shp_global[Shp_global$SCI_NAME==Data$SCI_NAME[i]]
    
    global <- project(global, "EPSG:6933")
    region <- project(region, "EPSG:6933")
    
    global <- makeValid(global)
    region <- makeValid(region)
    
    global_union <- aggregate(global)
    region_union <- aggregate(region)
    
    intersect_poly <- intersect(global_union, region_union)
    global_area <- expanse(global_union, unit="m")
    intersect_area <- expanse(intersect_poly, unit="m")
    
    Data$percent_range[i] <- (intersect_area / global_area) * 100
    
    print(paste('Did', i, 'of', nrow(Data)))
  }
  return(Data[,c("SCI_NAME", "percent_range")])
}

PR_odonates <- Range_percent_function(Shp_cropped = Sayer_FW_odonates_cropped, 
                               Shp_global = Sayer_FW_odonates, 
                               Data = All_species[All_species$Group=="FW_ODONATE",])
PR_odonates$Group <- 'Odonates'

PR_fish10 <- Range_percent_function(Shp_cropped = all_fish_shp, 
                               Shp_global = all_fish_shp_global, 
                               Data = All_species[All_species$Group=="FW_FISH",][1:10,])
PR_fish10$Group <- 'Fishes'

PR_fish20 <- Range_percent_function(Shp_cropped = all_fish_shp, 
                                    Shp_global = all_fish_shp_global, 
                                    Data = All_species[All_species$Group=="FW_FISH",][11:20,])
PR_fish20$Group <- 'Fishes'

PR_fish30 <- Range_percent_function(Shp_cropped = all_fish_shp, 
                                    Shp_global = all_fish_shp_global, 
                                    Data = All_species[All_species$Group=="FW_FISH",][21:26,])
PR_fish30$Group <- 'Fishes'

rm(all_fish_shp, all_fish_shp_global)
PR_fish <- rbind(PR_fish10, PR_fish20, PR_fish30)

PR_decapod <- Range_percent_function(Shp_cropped = Sayer_FW_decapods_cropped, 
                               Shp_global = Sayer_FW_decapods, 
                               Data = All_species[All_species$Group=="FW_DECAPOD",])
PR_decapod$Group <- 'Decapods'


PR_birds <- Range_percent_function(Shp_cropped = Sayer_FW_birds_cropped, 
                               Shp_global = Sayer_FW_birds, 
                               Data = All_species[All_species$Group=="THR_BIRDS",])
PR_birds$Group <- 'Birds'


PR_Mammals <- Range_percent_function(Shp_cropped = Sayer_FW_mammals_cropped, 
                               Shp_global = Sayer_FW_mammals, 
                               Data = All_species[All_species$Group=="THR_MAMMALS",])
PR_Mammals$Group <- 'Mammals'

PR_all <- rbind(PR_decapod, PR_fish, PR_odonates, PR_birds, PR_Mammals)
write.csv(PR_all, '../../results/species_occurrence/percent_range.csv', row.names=FALSE)

PR_all <- read.csv('../../results/species_occurrence/percent_range.csv')

rm(Sayer_FW_mammals, Sayer_FW_odonates, Sayer_FW_birds)

Plot_Percent_Range_fish <- 
ggplot(PR_all[PR_all$Group=='Fishes',], aes(percent_range, reorder(SCI_NAME, percent_range))) + 
  geom_point() +
  ylab('Binomial name') +
  xlab('% range contained in pilot area \n(hydrobasin level 4)')  +
  ggtitle('Freshwater fishes') +
  theme_bw()

Plot_Percent_Range_decapods <- 
  ggplot(PR_all[PR_all$Group=='Decapods',], aes(percent_range, reorder(SCI_NAME, percent_range))) + 
  geom_point() +
  ylab('Binomial name') +
  xlab('% range contained in pilot area \n(hydrobasin level 4)')  +
  ggtitle('Decapods') +
  theme_bw()

Plot_Percent_Range_odonates <- 
  ggplot(PR_all[PR_all$Group=='Odonates',], aes(percent_range, reorder(SCI_NAME, percent_range))) + 
  geom_point() +
  ylab('Binomial name') +
  xlab('% range contained in pilot area \n(hydrobasin level 4)')  +
  ggtitle('Odonates') +
  theme_bw()

Plot_Percent_Range_mammals <- 
  ggplot(PR_all[PR_all$Group=='Mammals',], aes(percent_range, reorder(SCI_NAME, percent_range))) + 
  geom_point() +
  ylab('Binomial name') +
  xlab('% range contained in pilot area \n(hydrobasin level 4)')  +
  ggtitle('Threatened mammals') +
  theme_bw()

Plot_Percent_Range_birds <- 
  ggplot(PR_all[PR_all$Group=='Birds',], aes(percent_range, reorder(SCI_NAME, percent_range))) + 
  geom_point() +
  ylab('Binomial name') +
  xlab('% range contained in pilot area \n(hydrobasin level 4)')  +
  ggtitle('Threatened birds') +
  theme_bw()

ggsave(
ggarrange(Plot_Percent_Range_decapods, Plot_Percent_Range_odonates, 
          Plot_Percent_Range_birds, Plot_Percent_Range_mammals, nrow=2, ncol=2), 
filename='../../results/species_occurrence/plots/percent_ranges_plots.pdf', height=8, width=8
)

ggsave(Plot_Percent_Range_fish, 
  filename='../../results/species_occurrence/plots/percent_ranges_plots_fish.pdf', height=6, width=6
)


# #########################################################################################################
# ## intersecting IUCN data mine sites with hydrobasins level 10
# 
# ## function to intersect, mine by mine
# Intersect_get_basinID <- function(basin_data_shp, mine_data_shp){
#   
#   IDs <- data.frame(Basin_ID=character(), Mine_ID=character())
#   
#   for (i in 1:length(mine_data_shp)) {
#     basins_with_mines <- basin_data_shp[relate(basin_data_shp, 
#                                                mine_data_shp[mine_data_shp$ID==mine_data_shp$ID[i]],
#                                                "intersects"), ]
#     IDs <- rbind(IDs, c(basins_with_mines$HYBAS_ID, basins_with_mines$PFAF_ID, mine_data_shp$NUMERO[i]))
#   }
#   colnames(IDs) <- c('Basin_ID', 'Basin_Pfaf_ID', 'Mine_ID')
#  return(IDs) 
# }
# 
# Level10 <- Intersect_get_basinID(basin_data_shp = Hydrobasins_level_10, mine_data_shp = MinePolygons)
# Level10$Hydrobasin_Level<- 'level_10'
# 
# ## intersecting mine sites with hydrobasins level 8 - actually, we need to find all the hydrobasins level 10 that fall within the 
# ## hydrobasins level 8. 
# 
# rel1 <- relate(centroids(Hydrobasins_level_10), Hydrobasins_levels_8[1], "within")
# bas10_in_8_1 <- Hydrobasins_level_10[rel1]
# 
# rel2 <- relate(centroids(Hydrobasins_level_10), Hydrobasins_levels_8[2], "within")
# bas10_in_8_2 <- Hydrobasins_level_10[rel2]
# 
# Level_8_composition_1 <- data.frame(Basin_ID_level_10=bas10_in_8_1$HYBAS_ID, PFAF_ID_level_10=bas10_in_8_1$PFAF_ID,
#                                     Hydrobasin_Level_8_PFAF_ID=Hydrobasins_levels_8$PFAF_ID[1])
# Level_8_composition_2 <- data.frame(Basin_ID_level_10=bas10_in_8_2$HYBAS_ID, PFAF_ID_level_10=bas10_in_8_2$PFAF_ID,
#                                     Hydrobasin_Level_8_PFAF_ID=Hydrobasins_levels_8$PFAF_ID[2])
# Level_8_composition <- rbind(Level_8_composition_1, Level_8_composition_2)
# rm(Level_8_composition_1, Level_8_composition_2, rel1, rel2, bas10_in_8_1, bas10_in_8_2)
# 
# ## adding mine ID 
# Mine_IDs1 <- c(MinePolygons[1]$NUMERO,
#                Hydrobasins_levels_8[relate(Hydrobasins_levels_8, MinePolygons[1],"intersects"), ]$PFAF_ID)
# Mine_IDs2 <- c(MinePolygons[2]$NUMERO,
#                Hydrobasins_levels_8[relate(Hydrobasins_levels_8, MinePolygons[2],"intersects"), ]$PFAF_ID)
# Mine_IDs3 <- c(MinePolygons[3]$NUMERO,
#                Hydrobasins_levels_8[relate(Hydrobasins_levels_8, MinePolygons[3],"intersects"), ]$PFAF_ID)
# Mine_IDs <- rbind(Mine_IDs1, Mine_IDs2)
# Mine_IDs <- rbind(Mine_IDs, Mine_IDs3)
# Mine_IDs <- as.data.frame(Mine_IDs)
# colnames(Mine_IDs) <- c('Mine_ID', 'Hydrobasin_level8_PFAF_ID')
# rm(Mine_IDs1, Mine_IDs2, Mine_IDs3)
# 
# ## Putting together the hydrobasins IDs -- modify from here? (PFAF IDs)
# Level10 <- left_join(Level10, Mine_IDs)
# Level10 <- Level10 %>% select(-Hydrobasin_Level)
# Level10 <- Level10[,c('Mine_ID', 'Basin_Pfaf_ID', 'Hydrobasin_level8_PFAF_ID')]
# colnames(Level10) <- c('Mine_ID', 'Hydrobasin_level_10_PFAF', 'Hydrobasin_level_8_PFAF')
# 
# Level_8_composition <- Level_8_composition %>% 
#   select(-Basin_ID_level_10)
# colnames(Level_8_composition) <- c('Hydrobasin_level_10_PFAF', 'Hydrobasin_level_8_PFAF')
# 
# 
# ## simple plot to visualise the area; adding rivers.
# 
# par(mfrow=c(2, 1))
# 
# plot(Hydrobasins_levels_4)
# plot(Hydrobasins_levels_8, col='bisque', add=TRUE)
# plot(Rivers_cropped, col='blue', add=TRUE, alpha=0.5)
# 
# plot(Hydrobasins_levels_8, col='bisque')
# plot(Hydrobasins_level_10[Hydrobasins_level_10$PFAF_ID %in% Level10$Hydrobasin_level_10_PFAF], col='coral', add=TRUE); 
# plot(Rivers_cropped, add=TRUE, col='blue')
# plot(MinePolygons, add=TRUE, col='black')
# 
# dev.off()
# 
# ## saving the relevant hydrobasin IDs
# write.csv(Level10, 'results/hydrobasin_relevant_level_10_IDs.csv', row.names = FALSE)
# write.csv(Level_8_composition, 'results/hydrobasin_level_8_ID_composition.csv', row.names = FALSE)
# 
# #########################################################################################################
# ## getting species-hydrobasin file data (for fish)
# 
# if(!file.exists('results/IUCN_fish_species_hydrobasin_data.csv')){
# Path_to_P_IUCN_data <- "P:/bec_data/100_rawdata/IUCN_ranges/v6.3_01-2026_FW_FISH/fish_hybas_table/"
# Species_hydrobasins <- list.files(Path_to_P_IUCN_data)
# Species_hydrobasins <- Species_hydrobasins[grepl('.csv', Species_hydrobasins)]
# 
# ## reading files 
# df_list <- lapply(as.list(paste0(Path_to_P_IUCN_data, Species_hydrobasins)), read.csv)
# species_data <- data.table::rbindlist(df_list)
# write.csv(species_data, 'results/IUCN_fish_species_hydrobasin_data.csv', row.names=FALSE)
# rm(Path_to_P_IUCN_data, Species_hydrobasins, df_list)
# 
# } else{
#   species_data <- read.csv("results/IUCN_fish_species_hydrobasin_data.csv")
#   }
# 
# ## check if any of the species pertain to hydrobasin 6 (continent: South America)
# species_data$hybas_id_level_1 <- sapply(species_data$hybas_id, function(x){return(substr(x, 1, 1))}) %>% 
#   as.numeric()
# unique(species_data$hybas_id_level_1)
# 
# ## there are some - having a look:
# species_data_level_1 <- species_data %>% 
#   filter(hybas_id_level_1==6)
# 
# length(unique(species_data_level_1$sci_name)) ## 5142 species for South America
# 
# #########################################################################################################
# ## extracting the relevant data - first, species for hydrobasin level 4 which constitutes our study region
# 
# Level_4_IDs <- substr(Hydrobasins_levels_4$PFAF_ID, 1, 4) %>% 
#   as.numeric() %>% 
#   unique()
# 
# species_data_level_1$hybas_id_level_4 <- sapply(species_data_level_1$hybas_id,
#                                                 function(x){return(substr(x, 1, 4))}) %>% 
#   as.numeric()
# 
# unique(species_data_level_1$hybas_id_level_4)
# 
# ## there are no species listed for this basin
# species_data_level_1 %>%  
#   filter(hybas_id_level_4==Level_4_IDs)







