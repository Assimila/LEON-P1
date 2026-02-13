## code to analyse the preliminary outputs of the LLM results - with a focus on studies that have investigated freshwater impacts 
## this is for LEON'S pilot 1 aims

library(dplyr)
library(ggplot2)
library(ggpattern)
library(ggpubr)
library(rnaturalearth)
library(ggalluvial)
library(tidyr)
`%nin%` <- Negate(`%in%`)

## loading data -- all sets 
Data <- read.csv("../../data/systematic_review/Extraction Update/output-rest_v8.csv",  sep=';')
Test <- read.csv("../../data/systematic_review/Extraction Update/output-test_v8.csv",  sep=';') %>% 
  select(-Comment)
Train <- read.csv("../../data/systematic_review/Extraction Update/output-train_v8.csv",  sep=';') %>% 
  select(-Comments)
Data <- rbind(Data, Test)
Data <- rbind(Data, Train)

## 147 studies were considered
unique(Data$Study.ID) %>% length()

## We focus on freshwater biomes
Studies_Biomes <- unique(Data[, c('Study.ID', 'Biomes.of.assessment')])
table(Studies_Biomes$Biomes.of.assessment)

FW_subset <- Data %>% 
  filter(grepl('Freshwater', Biomes.of.assessment))
length(unique(FW_subset$Study.ID)) ## 86 studies have considered freshwater biomes, over 147 studies (~59%)
length(unique(FW_subset$Study.ID))/length(unique(Data$Study.ID))*100

## we are particularly interested in understanding the use of TSS (or turbidity related parameters) in such studies.
## we need to reclassify the metrics. There are three types (biodiversity, sub-organismal, environmental)

######
## reclassifying all the metrics, for the studies that focused on freshwater biomes (for the biodiversity impacts)
## we reclassify the whole dataset to make sure we don't  miss out on some studies

## first check if the studies consider several types of metrics, or only one type of metrics
Data %>% 
  group_by(Study.ID) %>% 
  distinct(Metric.category) %>% 
  group_by(Study.ID) %>% 
  summarise(
    n_metric_types = n_distinct(Metric.category)) %>% 
  arrange(desc(n_metric_types)) %>% 
  group_by(n_metric_types) %>% 
  summarise(N_studies=n()) ## a few studies (20) seem to have considered only one type of metric.

###### ###### ###### ###### ###### ###### ###### 
###### reclassifying the biodiversity metrics
###### ###### ###### ###### ###### ###### ###### 

Biodiversity_metrics_all_raw <- 
  as.data.frame(unique(Data$Metric[Data$Metric.category=='Biodiversity metric']))
colnames(Biodiversity_metrics_all_raw) <- 'Biodiversity_metric_raw'
Biodiversity_metrics_all_raw <- Biodiversity_metrics_all_raw %>% 
  arrange(Biodiversity_metric_raw)
nrow(Biodiversity_metrics_all_raw) ## 988 different texts describing the biodiversity metrics

Biodiversity_metrics_all_raw$Metrics_reclassified_proxy <- NA

Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('occurrence', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'occurrence (presence/absence)'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('abundance|Abundance|density|Density|Aggregation of individuals', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'abundance/density'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Presence/absence|presence/absence|Presence', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'occurrence (presence/absence)'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('biomass|phytomass', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'biomass'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('cover|Cover', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'cover'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Beta|beta|β|similarity|Bray‑Curtis|Turnover component|Nestedness', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'beta diversity/similarity'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('γ', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'richness'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('richness|Richness|syntaxa count', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'richness'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Shannon', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'Shannon diversity index'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[Biodiversity_metrics_all_raw$Biodiversity_metric_raw=='Diversity (H′)'] <- 'Shannon diversity index'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Simpson', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'Simpson diversity index'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Pielou|Evenness|evenness', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'Pielou diversity index/evenness'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Brillouin', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'Brillouin diversity index'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Functional|functional|Life-cycle|Body size|Body-size|trophic diversity|Fish size distribution|Trophic Diversity|Mean maximum standard length of the species present at a site|Mean body length of G. laevifrons ', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'functional diversity'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('MVDISP|CA1|CA2|CA3|PCA|Correspondence|NMDS|RDA|DCA|PERMANOVA|ANOSIM|CCA|PCoA|MDS|Multivariate community structure', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'dimensionality reduction, community composition'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('MVDISP|PCA|Correspondence|NMDS|RDA|DCA|PERMANOVA|ANOSIM|CCA|PCoA|MDS|Multivariate community structure', Biodiversity_metrics_all_raw$Biodiversity_metric_raw) &
                                                          grepl('Beta|beta|β|similarity|Bray‑Curtis', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] <- 'beta diversity/dimensionality reduction, community composition'

## if not already assigned (is.na)
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('community composition|Community|composition|prey items', Biodiversity_metrics_all_raw$Biodiversity_metric_raw) &
                                                          is.na(Biodiversity_metrics_all_raw$Metrics_reclassified_proxy)] <- 'community composition'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Total number of', Biodiversity_metrics_all_raw$Biodiversity_metric_raw) &
                                                          is.na(Biodiversity_metrics_all_raw$Metrics_reclassified_proxy)] <- 'richness'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('%|Proportion|composition|Percentage of AMBI|Percentage share of each taxon|Percent of individuals', Biodiversity_metrics_all_raw$Biodiversity_metric_raw) &
                                                          is.na(Biodiversity_metrics_all_raw$Metrics_reclassified_proxy)] <- 'community composition'

## cases that need manual input
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('tadpoles per pool|Number of tadpoles|Number of ant individuals', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'abundance/density'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Ant species composition|Number of phytophagous species', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'richness'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Number of individuals|number of individuals', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'abundance/density'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Total number of macro‑invertebrate individuals collected per site', Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'abundance/density'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl('Margalef|Dietary diversity of captured fish|Number of bird species|Number of bacterial phyla detected |Propagule diversity |Number of introduced |Number of diatom species|Number of families|Number of orders|Number of ubiquitous species|Number of stream‑specialist species|Number of macro‑invertebrate taxa per sampling site',
                                                              Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'richness'


## diversity, unspecified elsewhere
Diversity_nes <-
  paste0(
    c('Oikopleuridae',
      'Oithonidae',
      'Other Crustaceans',
      'Overall macro‑invertebrate assessment',
      'Overall macro‑invertebrate diversity',
      'Paracalanidae', 
      'Procladius spp.',
      'Shredders',
      'Ctenotus',
      'Tanytarsus spp.',
      'Terrestrial insects in pan traps',
      'Aquatic insects in pan traps',
      'Input of aquatic insects to pan traps',
      'Input of terrestrial insects to pan traps',
      'Watanabe es ',
      'Watanabe sp ',
      'Watanabe sx ',
      'Nematode expected species number ES',
      'Feeding',
      'Burrowers',
      'Corbicula fluminea ',
      'Bivalvia ',
      'Crustacea ',
      'Chironomus neocorax',
      'copy number',
      'Bacterial diversity ',
      'Capture rate',
      'capture ra', 
      'Grandidierella sp',
      'Nematode diversity',
      'Locomotion ',
      'Connectance',
      'connectance',
      'Food‑web',
      'Number of trophic links',
      'Number of DGGE bands per sample',
      'Number of observations of each macroinvertebrate',
      'Number of unique 16S rRNA ribotypes', 
      'Taxa diversity',
      'Invertebrate drift count',
      'Filter feeders', 
      'Fish capture quantity', 
      'Fish mortality incidence',
      'Chao index', 
      'Rao’s quadratic entropy'
      

    ),
    collapse = "|"
  )
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl(Diversity_nes, Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'diversity index, n.e.s.'

## biomonitoring tools and indices
Biomonitoring <-
  paste0(
    c(
      'BMWP score', ## ecological tool
      'BMWP score per site', ## ecological tool
      'Biological Monitoring Working Party ', ##  ecological tool
      'BioMAP Water‑Quality Index ', ##  ecological tool
      'ASPT', ##  ecological tool
      'Acid‑Mine‑Drainage Diatom Index of Biotic Integrity',##  ecological tool
      'Nematode Maturity Index', ##  ecological tool
      'AMBI', 
      'WESI', ## Water Ecosystem State Index 
      'WQI', 
      'Biotic Integrity', 
      'Biotic Index', 
      'Ecological Quality Index', 
      'Ephemeroptera‑Plecoptera‑Trichoptera (EPT) family‑level index',
      'ICM‑Star index',
      'IMMi‑T index',
      'Biological Integrity',
      'Sládeček Class 1‑5',
      'WV‑SCI (macroinvertebrate index)', 
      'HBI', 'DKI', 'IBI ', 'SCI ', 'EQR',
      'Whalley‑Hawkes‑Paisley‑Trigg'
      
      
      
    ),
    collapse = "|"
  )

Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl(Biomonitoring, Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'biomonitoring tools and indices'


## spatial metrics
Spatial_metrics_nes <-
  paste0(
    c('Occupancy',
      '% of suitable habitat classified as',
      'Proportion of deforestation occurring in',
      'Proportion of ecosystem area within MPAs that falls into',
      'Area of high‑biological‑importance forest loss',
      'Range-Restriction Index'
    ),
    collapse = "|"
  )
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl(Spatial_metrics_nes, Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'spatial metrics'
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl(Spatial_metrics_nes, Biodiversity_metrics_all_raw$Biodiversity_metric_raw)] 

## these cases seem to report an effect size
Cases_ES <-
  paste0(
    c(
      '% reduction in benthic‑invertebrate species richness',
      '% of taxa lost above EPA benchmark',
      'median bird potential distribution affected',
      'median anuran potential distribution affected',
      'of pixels suitable for', 
      'bird ranges directly affected', 
      'bird ranges indirectly', 
      'anuran ranges indirectly',
      'anuran ranges directly',
      'Species‑specific % of range affected',
      '% reduction in benthic‑invertebrate species richness',
      '% reduction in benthic‑invertebrate abundance',
      'Difference in Plecoptera % (up‑stream vs. down‑stream of a mine adit)',
      'Ecosystem‑sensitivity effect size',
      'Number of species with significant change',
      'Effect of distance from the mine edge on fungal observed richness'
    ),
    collapse = "|"
  )

Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl(Cases_ES, Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'effect size'


## these cases seem to report a model coefficient
Cases_ModelOutput <-
  paste0(
    c('coefficient',
      'Model Affinity',
      'percent‑model‑affinity',
      'Indicator-species association', 'Indicator‑species', 'Indicator‑taxa'),
    collapse = "|"
  )

Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl(Cases_ModelOutput, Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'model output'

## unknows
Unknowns <-
  paste0(
    c('B-', 'R index', 'Random runs value', 
      'Impact index (I_c)', 'Species saturation', 'AMD’ index'
      
    ),
    collapse = "|"
  )

Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[grepl(Unknowns, Biodiversity_metrics_all_raw$Biodiversity_metric_raw)]  <- 'undetermined'

## the rest is still to check
Biodiversity_metrics_all_raw$Metrics_reclassified_proxy[is.na(Biodiversity_metrics_all_raw$Metrics_reclassified_proxy)]  <- 'presently unclassified'

############ visualising results

Biodiversity_metrics_all_raw  %>%
  filter(is.na(Metrics_reclassified_proxy)) %>%
  nrow()

colnames(Biodiversity_metrics_all_raw)[1] <- 'Metric' 
Data <- left_join(Data, Biodiversity_metrics_all_raw)

Plot_biodiversity_indices <- 
Data %>% 
  filter(grepl('Freshwater', Biomes.of.assessment)) %>% 
  filter(Metric.category=='Biodiversity metric') %>% 
  #filter(!Metrics_reclassified_proxy %in% c('model output', 'effect size')) %>% 
  group_by(Metrics_reclassified_proxy) %>% 
  summarise(N=n()) %>% 
  arrange(desc(N)) %>% 
  as.data.frame() %>% 
  mutate(Status=ifelse(Metrics_reclassified_proxy %in% c('undetermined', 'presently unclassified'), 
                       'to determine', 'reclassified'))%>% 
  mutate(Percent=N/sum(N)*100) %>% 
  mutate(Percent_reclassified=N/(sum(N)-206)*100)
 
Dist_Biodiv_Metrics <- 
ggplot(Plot_biodiversity_indices, aes(x = reorder(Metrics_reclassified_proxy, N), y=N, fill=Status)) + 
  theme_bw() +
  geom_bar(stat = "identity", col='black') +
  ylab('Count (total among rows)') + xlab('') +
  ggtitle('Biodiversity metrics (reclassified)') +
  #theme(axis.text.x = element_text(angle = 45, hjust=1)) +
  theme(text=element_text(size=12, 
                          family="serif"), 
        legend.position = 'bottom') +
  scale_fill_manual(values = c('lightblue', 'steelblue')) +
  geom_text(aes(label=N), position="stack", hjust=-0.3, size = 3) +
  coord_flip() 
ggsave(Dist_Biodiv_Metrics, filename='../../results/systematic_review/plots/dist_biodiv_metrics.pdf', height = 8, width = 10)

rm(Diversity_nes, Cases_ES, Biomonitoring, Spatial_metrics_nes, Unknowns , Cases_ModelOutput)


###### ###### ###### ###### ###### ###### ###### 
###### reclassifying the sub-organismal metrics
###### ###### ###### ###### ###### ###### ###### 

Suborg_metrics_all_raw <- 
  as.data.frame(unique(Data$Metric[Data$Metric.category=='(Sub)-organismal metric']))
colnames(Suborg_metrics_all_raw) <- 'Suborganismal_metric_raw'
Suborg_metrics_all_raw <- Suborg_metrics_all_raw %>% 
  arrange(Suborganismal_metric_raw)
nrow(Suborg_metrics_all_raw) ## 369 different texts describing the biodiversity metrics

Suborg_metrics_all_raw$Metrics_reclassified_proxy <- NA

Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Zn ', 
                                                      Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Zn concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('As concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'As concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Pb ', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Pb concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Cd ', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Cd concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Cr ', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Cr concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Cu ', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Cu concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Fe ', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Fe concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Hg |Mercury |mercury', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Hg concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Ni ', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Ni concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Ba ', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Ba concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Mn ', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Mn concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Sr ', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Sr concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Tl concentration|Thallium concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Tl concentration'

Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Cobalt concentration|Co concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Co concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Rubidium concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Rb concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Selenium concentration|Tissue Se concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Se concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Plasma phosphorus', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'P concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Li concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Li concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Plasma calcium', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Ca concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('V concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'V concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Chlorophyll-a concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'chlorophyll-a concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Chlorophyll.*a concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'chlorophyll-a concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Chlorophyll.*b concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'chlorophyll-b concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('c₂ concentration', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'chlorophyll-c1+c2 concentration'

Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="As"] <- 'As concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Ag"] <- 'Ag concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Al"] <- 'Al concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Zn"] <- 'Zn concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Cd"] <- 'Cd concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Co"] <- 'Co concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Cu"] <- 'Cu concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Cr"] <- 'Cr concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Fe"] <- 'Fe concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Pb"] <- 'Pb concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Hg"] <- 'Hg concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Mn"] <- 'Mn concentration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[Suborg_metrics_all_raw$Suborganismal_metric_raw=="Ni"] <- 'Ni concentration'

Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Metallothionein', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Metallothionein concentration/induction'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Lipid', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Lipid peroxidation'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Trace‑metal concentration|Metal concentrations (Pb, Cd, Zn, Cu)|Cd, Cu, Hg, Pb, Zn|Metal concentrations (Pb, Cd, Zn, Cu)', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'Trace‑metal concentrations|several metal concentrations'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('activity|Lactate', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'enzyme activity (phosphatase, catalase, dehydrogenase, dismutase, etc.)'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl(' developmental abnormalities', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'developmental abnormalities'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl(' morphology', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'cell morphology'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Copy number|copy number', 
                                                        Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'bacterial copy number'


Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('expression', Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'gene expression'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('respiration', Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'respiration'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('survival', Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'survival'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('histopathology|Histological', Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'histopathology/histology'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Hepatic', Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'hepathic processes'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('growth', Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'growth'
Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('Salmon liver size|body size|eye size|Body-length|body weight|body length|body condition', Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'body condition/organ size'

Suborg_metrics_all_raw$Metrics_reclassified_proxy[grepl('OTU richness', Suborg_metrics_all_raw$Suborganismal_metric_raw)] <- 'OTU richness'

## the rest is still to check
Suborg_metrics_all_raw$Metrics_reclassified_proxy[is.na(Suborg_metrics_all_raw$Metrics_reclassified_proxy)]  <- 'presently unclassified'

colnames(Suborg_metrics_all_raw)[1] <- 'Metric' 
colnames(Suborg_metrics_all_raw)[2] <- 'SubO_Metrics_reclassified_proxy' 

Data_sub <- left_join(Data, Suborg_metrics_all_raw)

Plot_suborg_indices <- 
  Data_sub %>% 
  filter(grepl('Freshwater', Biomes.of.assessment)) %>% 
  filter(Metric.category=='(Sub)-organismal metric') %>% 
  #filter(!Metrics_reclassified_proxy %in% c('model output', 'effect size')) %>% 
  group_by(SubO_Metrics_reclassified_proxy) %>% 
  summarise(N=n()) %>% 
  arrange(desc(N)) %>% 
  as.data.frame() %>% 
  mutate(Status=ifelse(SubO_Metrics_reclassified_proxy %in% c('undetermined', 'presently unclassified'), 
                       'to determine', 'reclassified'))

Dist_SubO_Metrics <- 
  ggplot(Plot_suborg_indices, aes(x = reorder(SubO_Metrics_reclassified_proxy, N), y=N, fill=Status)) + 
  theme_bw() +
  geom_bar(stat = "identity", col='black') +
  ylab('Count (total among rows)') + xlab('') +
  ggtitle('Sub-organismal metrics, reclassified (best proxy)') +
  #theme(axis.text.x = element_text(angle = 90, hjust=1)) +
  theme(text=element_text(size=12, 
                          family="serif"), 
        legend.position = 'bottom') +
  scale_fill_manual(values = c('wheat', 'tan2')) +
  geom_text(aes(label=N), position="stack", hjust=-0.3, size = 3) +
  coord_flip()

ggsave(Dist_SubO_Metrics, filename='../../results/systematic_review/plots/dist_suborg_metrics.pdf', height = 8, width = 12)

# x <- 
# Suborg_metrics_all_raw %>% 
#   filter(is.na(Metrics_reclassified_proxy)) %>%
#   nrow()
# x/nrow(Suborg_metrics_all_raw)*100
# 
# Suborg_metrics_all_raw %>% nrow()

###### ###### ###### ###### ###### ###### ###### 
###### reclassifying the environmental metrics
###### ###### ###### ###### ###### ###### ###### 

Env_metrics_all_raw <- 
  as.data.frame(unique(Data$Metric[Data$Metric.category=='Environmental metric']))
colnames(Env_metrics_all_raw) <- 'Environmental_metric_raw'
Env_metrics_all_raw <- Env_metrics_all_raw %>% 
  arrange(Environmental_metric_raw)
nrow(Env_metrics_all_raw) ## 1058 different texts describing the biodiversity metrics

Env_metrics_all_raw$Metrics_reclassified_proxy <- NA


Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('turbidity|Turbidity|TSS|suspended solids|Suspended Solids|Secchi depth|TSM|Suspended particulate matter|Suspended matter|suspended matter|particles', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'total suspended solids/turbidity/particles'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('TDS|Dissolved Solids|dissolved solids', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'total dissolved solids'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Chlorophyll a|Chlorophyll‑a|chlorophyll‑a', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'chlorophyll‑a concentration'

Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Mo ', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Mo concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Sulfate|sulfate|Sulphate', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'sulfate concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Al concentration|Aluminium|aluminium|Aluminum', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Al concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Co |Cobalt|cobalt|of Co', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Co concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Fe |iron |Iron', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Fe concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Pg |lead |Lead |lead |Pb |Dissolved Pb|Total Pb', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Pb concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Hg |Mercury|mercury', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Hg concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('phosphorus', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'phosphorus concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Barium|Ba ', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Ba concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Sr ', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Sr concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Cu |Copper|copper|dissolved Cu|Dissolved Cu|of Cu|Total Cu', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Cu concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Arsenic|arsenic|As ', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'As concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Cadmium|cadmium|Cd |Dissolved Cd', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Cd concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Zinc|Zn |Dissolved Zn|dissolved Zn|of Zn|Dissolved zinc|zinc concentration|Total zinc', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Zn concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Chlorite|Cl |Chloride', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Cl/Chlorite/chloride concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Nitrate', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'nitrate concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('phosphate|Phosphate|phosphorus ', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'phospate/phosphorus concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Ni concentration|Nickel|nickel|Ni |of Ni|Total Ni', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Ni concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Arsenic concentration|As |dissolved As', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'As concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Manganese|manganese|Mn |of Mn', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Mn concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Magnesium|magnesium|Mg ', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Mg concentration'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Ca |calcium|Calcium |Hardness|hardness', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Ca concentration/hardness'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Cr |Chromium', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'Cr concentration'

Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Nitrogen|nitrogen|Ammon', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'nitrogen/ammonium concentration'

Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Alkalinity|alkalinity', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'alkalinity'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('pH', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'pH'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('temperature|Temperature|Acidity', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'temperature'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Dissolved oxygen|Dissolved Oxygen|Dissolved O₂|Dissolved‑O₂|dissolved‑oxygen', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'dissolved oxygen'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('metal concentrations|metals|Fe, Zn, Cu concentrations|Dissolved anion concentrations|Dissolved inorganic nutrient concentrations', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'chemical concentrations (misc.)'


Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Dissolved organic carbon|Dissolved Organic Carbon', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'dissolved organic carbon'

Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Chemical Oxygen Demand|Chemical oxygen demand', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'chemical oxygen demand'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Biological oxygen demand|Biological Oxygen Demand|Biochemical Oxygen Demand|Biochemical oxygen demand', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'biological oxygen demand'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Conductivity|conductivity', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'electrical conductivity'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('NDVI', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'NDVI'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Deforestation|deforestation', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'deforestation'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl(' stream discharge| Stream discharge|Discharge|median discharge', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'discharge'
Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('organic matter|organic‑matter|Organic‑matte|TOC|Organic‑C content', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'organic matter content'

Env_metrics_all_raw$Metrics_reclassified_proxy[grepl('Grain‑size|Particle‑size|particle size', 
                                                     Env_metrics_all_raw$Environmental_metric_raw)] <- 'particle size'


x <- 
  Env_metrics_all_raw %>% 
  filter(is.na(Metrics_reclassified_proxy)) %>%
  nrow()
x/nrow(Env_metrics_all_raw)*100

## the rest is still to check
Env_metrics_all_raw$Metrics_reclassified_proxy[is.na(Env_metrics_all_raw$Metrics_reclassified_proxy)]  <- 'presently unclassified'

colnames(Env_metrics_all_raw)[1] <- 'Metric' 
colnames(Env_metrics_all_raw)[2] <- 'Env_Metrics_reclassified_proxy' 

Data_env <- left_join(Data, Env_metrics_all_raw)

Plot_env_indices <- 
  Data_env %>% 
  filter(grepl('Freshwater', Biomes.of.assessment)) %>% 
  filter(Metric.category=='Environmental metric') %>% 
  #filter(!Metrics_reclassified_proxy %in% c('model output', 'effect size')) %>% 
  group_by(Env_Metrics_reclassified_proxy) %>% 
  summarise(N=n()) %>% 
  arrange(desc(N)) %>% 
  as.data.frame() %>% 
  mutate(Status=ifelse(Env_Metrics_reclassified_proxy %in% c('undetermined', 'presently unclassified'), 
                       'to determine', 'reclassified')) %>% 
  mutate(Percent=N/sum(N)*100) %>% 
  mutate(Percent_reclassified=N/(sum(N)-206)*100)
  

Dist_Env_Metrics <- 
  ggplot(Plot_env_indices, aes(x = reorder(Env_Metrics_reclassified_proxy, N), y=N, fill=Status)) + 
  theme_bw() +
  geom_bar(stat = "identity", col='black') +
  ylab('Count (total among rows)') + xlab('') +
  ggtitle('Environmental metrics, reclassified (best proxy)') +
  #theme(axis.text.x = element_text(angle = 45, hjust=1)) +
  theme(text=element_text(size=12, 
                          family="serif"), 
        legend.position = 'bottom') +
  scale_fill_manual(values = c('palegreen', 'palegreen4')) +
  geom_text(aes(label=N), position="stack", hjust=-0.3, size = 3) +
  coord_flip()

ggsave(Dist_Env_Metrics, filename='../../results/systematic_review/plots/dist_env_metrics.pdf', height = 8, width = 8.5)


###### ###### ###### ###### ###### ###### ###### 
## collating the data together
###### ###### ###### ###### ###### ###### ###### 

Data_1 <- Data[Data$Metric.category=='Biodiversity metric',]
Data_2 <- Data_sub[Data$Metric.category=='(Sub)-organismal metric',] %>% 
  select(-Metrics_reclassified_proxy)  
colnames(Data_2)[ncol(Data_2)] <- 'Metrics_reclassified_proxy'
Data_3 <- Data_env[Data$Metric.category=='Environmental metric',] %>% 
  select(-Metrics_reclassified_proxy)  
colnames(Data_3)[ncol(Data_3)] <- 'Metrics_reclassified_proxy'

DataAll <- rbind(Data_1, Data_2)
DataAll <- rbind(DataAll, Data_3)

## focussing on studies that have considered freshwater biomes
Data_FW <- DataAll %>% 
  filter(grepl('Freshwater', Biomes.of.assessment))

Data_FW$Taxonomic_group_reclassified <- NA

TaxGroups <- Data_FW$Taxonomic.groups[is.na(Data_FW$Taxonomic_group_reclassified)] %>%  unique()

## macroinverts
Macroinvertebrates <- grepl('invertebrate|mussel|bivalve|mollusc|crabs|Chironomidae', Data_FW$Taxonomic.groups)
Data_FW$Taxonomic_group_reclassified[Macroinvertebrates] <- 'macroinvertebrates'

## fish
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("fish|salmon|Fish", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & fish"),
          "fish"
        ),
        Taxonomic_group_reclassified
      )
  )

## aqautic insects
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("aquatic insect|Aquatic insects", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & aquatic insects"),
          "aquatic insects"
        ),
        Taxonomic_group_reclassified
      )
  )

## diatoms
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("algae|diatoms|Diatoms", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & algae"),
          "algae"
        ),
        Taxonomic_group_reclassified
      )
  )

## amphibians
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("Amphibian", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & amphibians"),
          "amphibians"
        ),
        Taxonomic_group_reclassified
      )
  )

## bacterial communities
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("Bacteria|bacteria", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & microbial communities"),
          "microbial communities"
        ),
        Taxonomic_group_reclassified
      )
  )

## birds
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("Birds|birds", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & birds"),
          "birds"
        ),
        Taxonomic_group_reclassified
      )
  )

## plants
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("plants|Plants", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & plants"),
          "plants"
        ),
        Taxonomic_group_reclassified
      )
  )


## meiofauna
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("Nematodes", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & meiofauna"),
          "meiofauna"
        ),
        Taxonomic_group_reclassified
      )
  )

## fungi
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("fungi", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & fungi"),
          "fungi"
        ),
        Taxonomic_group_reclassified
      )
  )


## plankton
Data_FW <- Data_FW %>%
  mutate(
    Taxonomic_group_reclassified =
      if_else(
        grepl("plankton", Taxonomic.groups),
        if_else(
          !is.na(Taxonomic_group_reclassified),
          paste0(Taxonomic_group_reclassified, " & plankton"),
          "plankton"
        ),
        Taxonomic_group_reclassified
      )
  )

## which taxonomic groups & impact pathways are most studied? Where are the studies from?
Tax_studies <- Data_FW %>% 
  select(Country.Continent, Study.ID, Taxonomic_group_reclassified, Impact.pathway) 
Tax_studies <- unique(Tax_studies)

## map of countries
Tax_studies %>%  
  group_by(Country.Continent) %>%
  summarise(N=n())%>% 
  as.data.frame() 
Tax_studies$Country_reclass <- NA
Tax_studies$Country_reclass[grepl('Australia', Tax_studies$Country.Continent)] <- 'Australia'
Tax_studies$Country_reclass[grepl('Bolivia', Tax_studies$Country.Continent)] <- 'Australia'
Tax_studies$Country_reclass[grepl(' Bolivia, Argentina, Paraguay', Tax_studies$Country.Continent)] <- ' Bolivia, Argentina, Paraguay'
Tax_studies$Country_reclass[grepl('Brazil', Tax_studies$Country.Continent)] <- 'Brazil'
Tax_studies$Country_reclass[grepl('Canada', Tax_studies$Country.Continent)] <- 'Canada'
Tax_studies$Country_reclass[grepl('China', Tax_studies$Country.Continent)] <- 'China'
Tax_studies$Country_reclass[grepl('Colombia', Tax_studies$Country.Continent)] <- 'Colombia'
Tax_studies$Country_reclass[grepl('Costa Rica', Tax_studies$Country.Continent)] <- 'Costa Rica'
Tax_studies$Country_reclass[grepl('Democratic Republic of Congo', Tax_studies$Country.Continent)] <- 'Dem. Rep. Congo'
Tax_studies$Country_reclass[grepl('Spain', Tax_studies$Country.Continent)] <- 'Spain'
Tax_studies$Country_reclass[grepl('Ecuador', Tax_studies$Country.Continent)] <- 'Ecuador'
Tax_studies$Country_reclass[grepl('Finland', Tax_studies$Country.Continent)] <- 'Finland'
Tax_studies$Country_reclass[grepl('France', Tax_studies$Country.Continent)] <- 'France'
Tax_studies$Country_reclass[grepl('French Guiana', Tax_studies$Country.Continent)] <- 'French Guiana'
Tax_studies$Country_reclass[grepl('Germany', Tax_studies$Country.Continent)] <- 'Germany'
Tax_studies$Country_reclass[grepl('India', Tax_studies$Country.Continent)] <- 'India'
Tax_studies$Country_reclass[grepl('Indonesia', Tax_studies$Country.Continent)] <- 'Indonesia'
Tax_studies$Country_reclass[grepl('Ireland', Tax_studies$Country.Continent)] <- 'Ireland'
Tax_studies$Country_reclass[grepl('Italy', Tax_studies$Country.Continent)] <- 'Italy'
Tax_studies$Country_reclass[grepl('Japan', Tax_studies$Country.Continent)] <- 'Japan'
Tax_studies$Country_reclass[grepl('Mexico', Tax_studies$Country.Continent)] <- 'Mexico'
Tax_studies$Country_reclass[grepl('New Zealand', Tax_studies$Country.Continent)] <- 'New Zealand'
Tax_studies$Country_reclass[grepl('Nigeria', Tax_studies$Country.Continent)] <- 'Nigeria'
Tax_studies$Country_reclass[grepl('Norway', Tax_studies$Country.Continent)] <- 'Norway'
Tax_studies$Country_reclass[grepl('Peru', Tax_studies$Country.Continent)] <- 'Peru'
Tax_studies$Country_reclass[grepl('Poland', Tax_studies$Country.Continent)] <- 'Poland'
Tax_studies$Country_reclass[grepl('Portugal', Tax_studies$Country.Continent)] <- 'Portugal'
Tax_studies$Country_reclass[grepl('Romania', Tax_studies$Country.Continent)] <- 'Romania'
Tax_studies$Country_reclass[grepl('Russia', Tax_studies$Country.Continent)] <- 'Russia'
Tax_studies$Country_reclass[grepl('South Africa', Tax_studies$Country.Continent)] <- 'South Africa'
Tax_studies$Country_reclass[grepl('South Korea', Tax_studies$Country.Continent)] <- 'South Korea'
Tax_studies$Country_reclass[grepl('Spain', Tax_studies$Country.Continent)] <- 'Spain'
Tax_studies$Country_reclass[grepl('United Kingdom', Tax_studies$Country.Continent)] <- 'United Kingdom'
Tax_studies$Country_reclass[grepl('United States', Tax_studies$Country.Continent)] <- 'United States'
Tax_studies$Country_reclass[grepl('Zimbabwe', Tax_studies$Country.Continent)] <- 'Zimbabwe'

CountriesFreq <- Tax_studies %>%  
  group_by(Country_reclass) %>%
  summarise(N=n())%>% 
  as.data.frame() 
colnames(CountriesFreq)[1] <- 'country'

world <- ne_countries(scale = "medium", returnclass = "sf")
world_data <- world %>%
  left_join(CountriesFreq, by = c("name" = "country"))

ggsave(filename = '../../results/systematic_review/plots/Study_map.pdf',
ggplot(world_data) +
  geom_sf(aes(fill = as.factor(N))) +
  scale_fill_viridis_d(na.value = "grey90", option = 'D') +
  theme_minimal() +
  labs(fill = "Number of studies") + ggtitle('Geographical distribution of studies') 
)

Split <- Tax_studies %>%
  tidyr::separate_rows(Taxonomic_group_reclassified, sep = "\\s*&\\s*") %>% 
  tidyr::separate_rows(Impact.pathway, sep = "\\s*,\\s*")

TaxGroups <- 
Split %>% 
  group_by(Taxonomic_group_reclassified) %>% 
  summarise(N_studies=n()) %>% 
  as.data.frame() %>% 
  arrange(desc(N_studies))

ImpactGroups <- 
Split %>% 
  group_by(Impact.pathway) %>% 
  summarise(N_studies=n()) %>% 
  as.data.frame() %>% 
  arrange(desc(N_studies))

Dist_tax_groups_studies <- 
  ggplot(TaxGroups, aes(x = reorder(Taxonomic_group_reclassified, N_studies), y=N_studies)) + 
  theme_bw() +
  geom_bar(stat = "identity", col='black', fill='coral') +
  ylab('Number of studies') + xlab('') +
  ggtitle('Taxonomic groups under consideration among studies') +
  #theme(axis.text.x = element_text(angle = 90, hjust=1)) +
  theme(text=element_text(size=16, 
                          family="serif"), 
        legend.position = 'bottom') +
  geom_text(aes(label=N_studies), position="stack", hjust=-0.3, size = 3) +
  coord_flip()

Dist_impact_pathways_studies <- 
  ggplot(ImpactGroups, aes(x = reorder(Impact.pathway, N_studies), y=N_studies)) + 
  theme_bw() +
  geom_bar(stat = "identity", col='black', fill='magenta4') +
  ylab('Number of studies') + xlab('') +
  ggtitle('Impact pathways under consideration among studies') +
  #theme(axis.text.x = element_text(angle = 90, hjust=1)) +
  theme(text=element_text(size=16, 
                          family="serif"), 
        legend.position = 'bottom') +
  geom_text(aes(label=N_studies), position="stack", hjust=-0.3, size = 3) +
  coord_flip()

ggarrange(Dist_tax_groups_studies, Dist_impact_pathways_studies, nrow=2)
ggsave(ggarrange(Dist_tax_groups_studies, Dist_impact_pathways_studies, nrow=2),
       filename='../../results/systematic_review/plots/dist_tax_impact_pathways_studies.pdf', height = 8, width = 8)

ggsave(Dist_impact_pathways_studies, filename='../../results/systematic_review/plots/dist_impact_pathways_studies.pdf', height = 4, width = 8)
ggsave(Dist_tax_groups_studies, filename='../../results/systematic_review/plots/dist_tax_groups_studies.pdf', height = 4, width = 8)

## How many studies considered TSS and chlorophyll a?
TSS_Chlora_studies <- Data_FW %>% 
  select(Study.ID, Taxonomic_group_reclassified, Metric.category, Metrics_reclassified_proxy) 

TSS_Chlora_studies %>% 
  filter(Metric.category =='Environmental metric',
         Metrics_reclassified_proxy %in% c('total suspended solids/turbidity/particles', 'chlorophyll‑a concentration')) %>% 
  group_by(Metrics_reclassified_proxy) %>%  
  distinct(Study.ID) %>% 
  summarise(N=n())
  
Studies_TSS <- TSS_Chlora_studies %>% 
  filter(Metric.category =='Environmental metric',
         Metrics_reclassified_proxy %in% c('total suspended solids/turbidity/particles')) %>% 
  distinct(Study.ID) %>% 
  pull()

TSS_data <- TSS_Chlora_studies %>% 
  filter(Study.ID %in% Studies_TSS) %>% 
  filter(Metric.category!='(Sub)-organismal metric')
TSS_data <- unique(TSS_data)



