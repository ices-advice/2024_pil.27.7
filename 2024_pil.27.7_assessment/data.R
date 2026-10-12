# Script information -----------------------------------------------------------
# Title: pil.27.7
# Authors: Joseph Ribeiro, Rosana Ourens-Chans, Susan Kenyon
# Date created: 2022/05/26
# Purpose: This script processes catch and landings data to produce summary stats and tables for the report.
# Working directory: root (applies to all the TAF .r files)

# Load libraries ---------------------------------------------------------------
library(rstudioapi) # This has been written as an R studio project using RStudio Version 1.4.1717 
library(icesTAF)
library(icesTAF)
library(plyr)
library(ggplot2)
library(reshape)
library(dplyr)
library(tidyr)

# Set working directory --------------------------------------------------------
try(setwd(dirname(getActiveDocumentContext()$path)))
wdir = getwd(); print(wdir)
mkdir('boot/data')

# Define current year, data year, and advice year ------------------------------
thisyear <- as.numeric(format(Sys.Date(), "%Y"))
adviceyear = thisyear + 1
datayear = thisyear - 1 # The last year with complete landings data will be the previous year
cat(thisyear,file=paste0(wdir,"/boot/data/thisyear.txt"),sep="\n") # Where possible, define everything relative to this.
cat(adviceyear,file=paste0(wdir,"/boot/data/adviceyear.txt"),sep="\n")
cat(datayear,file=paste0(wdir,"/boot/data/datayear.txt"),sep="\n")

# Correcting French data -------------------------------------------------------

# France updated their landings data to 2020 for the benchmark in 2021 but these reviewed data were not uploaded to Intercatch. Old comment from 2021 states: "We need to replace the data from France in intercatch with the data from the ascension folder. The data in intercatch was only for three years and it did not include information by rectangle"
# In 2022, 2023, and 2024 the correct 1999-2020 data in "review landings_France.csv" were not uploaded to Intercatch. Data from 2021-2024 in Intercatch matched those in accessions so are assumed to be correct and do not need to be replaced.

Catches <- read.taf(paste0(wdir,"/boot/initial/data/LandingsOnly.csv"))
Catches <- subset(Catches, Caton>0)
Catches$Country <- as.factor(Catches$Country)
Catches$CatchCategory <- as.factor(Catches$CatchCategory)
Catches <- subset(Catches,!(Country=="France"&CatchCategory=="Landings"&Year>1999&Year<2020))
France_data_final <- read.csv(paste0(wdir,"/boot/initial/data/review landings_France.csv"))
Catches <- rbind(Catches,France_data_final)
Catches <- Catches[Catches$SeasonType=='Quarter',]

write.taf(Catches,paste0(wdir,"/boot/data/Catches.csv"),quote=TRUE)

# Now we begin defining data objects which are called on later in later r files
# Define catches by metier -----------------------------------------------------

# Standardise metiers - check whether there are any new fleets which should be classes as "other"

#PS = purse seine
Catches$metier2 <- ifelse(Catches$Fleet=="PS_SPF_0_0_0","PS_SPF_0_0_0","Other")

#OTM = otter trawl medium (SPF = pelagic)
Catches$metier2 <- ifelse(Catches$Fleet=="OTM_SPF_32-69_0_0_all","OTM_SPF_32-69_0_0_all",Catches$metier2)
Catches$metier2 <- ifelse(Catches$Fleet=="OTM_SPF_16-31_0_0","OTM_SPF_16-31_0_0",Catches$metier2)
Catches$metier2 <- ifelse(Catches$Fleet=="OTM_SPF_70-99_0_0_all","OTM_SPF_70-99_0_0_all",Catches$metier2)

#OTB = otter trawl bottom (SPF = pelagic)
Catches$metier2 <- ifelse(Catches$Fleet=="OTB_SPF_32-69_0_0_all","OTB_SPF_32-69_0_0_all",Catches$metier2)
Catches$metier2 <- ifelse(Catches$Fleet=="OTB_SPF_70-99_0_0_all","OTB_SPF_70-99_0_0_all",Catches$metier2)

# gill nets (but classed incorrectly here, they are actually purse seine ring nets)
Catches$metier2 <- ifelse(Catches$Fleet=="GNS_DEF_all_0_0_all","PS_SPF_0_0_0",Catches$metier2)
Catches$metier2 <- ifelse(Catches$Fleet=="GTR_DEF_all_0_0_all","PS_SPF_0_0_0",Catches$metier2)

# pelagic trawl medium
Catches$metier2 <- ifelse(Catches$Fleet=="PTM_SPF_16-31_0_0_all","PTM_SPF_16-31_0_0_all",Catches$metier2)
Catches$metier2 <- ifelse(Catches$Fleet=="PTM_SPF_32-69_0_0_all","PTM_SPF_32-69_0_0_all",Catches$metier2)
Catches$metier2 <- ifelse(Catches$Fleet=="Pelagic trawl","Pelagic trawl",Catches$metier2)

# SSC and SDN are Scottish Fly Seining and Danish Anchor Seining, respectively.
# These are not a type of purse seine and are therefore classed as other.
# Until 2023, SSC_DEF_70-99_0_0_all was erroneously classed as purse seine in this code.

Catches$metier2 <- as.factor(Catches$metier2)

# Subset from 2002 onwards
# We use data from 2002 to compare data among countries, as Scotland did not report data from previous years
Catch2002 <- subset(Catches, Year>2001)

write.taf(Catches,paste0(wdir,"/boot/data/Catches_metier.csv"),quote=TRUE)

mkdir("output")
inpDir <- ("data")
outDir <- ("output")

# Catches by category ----------------------------------------------------------
# Catches are either landed or discarded and landings could be below minimum size (BMS)
# 3 categories (Landings, discards, BMS landings)

# Discards reported in 2005 by the UK were very high and not representative of the fishery. It was when the sampling programme for discards started and they sampled vessels not targeting sardine.I'll delete this value
Catch2002b <- subset(Catch2002, !(Year==2005&Country=="UK (England)"&CatchCategory=="Discards"&Caton==62327359))

CatchCat <- ddply(Catch2002b,.(Year, CatchCategory),summarize,Catch=sum(Caton)/1000) 
catchadvicesheet <- reshape(CatchCat,direction="wide",idvar="Year", timevar="CatchCategory")

totalcatch <- sum(CatchCat$Catch[CatchCat$Year == datayear])
landingssum <- sum(CatchCat$Catch[CatchCat$Year == datayear & CatchCat$CatchCategory != "Discards"])
discards <- sum(CatchCat$Catch[CatchCat$Year == datayear & CatchCat$CatchCategory == "Discards"])

if(!"Biomass index (total area)" %in% colnames(catchadvicesheet)){catchadvicesheet$`Biomass index (total area)` = 0}
if(!"High" %in% colnames(catchadvicesheet)){catchadvicesheet$High = 0}
if(!"Low" %in% colnames(catchadvicesheet)){catchadvicesheet$Low = 0}

write.taf(catchadvicesheet,"boot/data/Catch_advice sheet.csv")

# Landings by country ----------------------------------------------------------
Lan2002 <- subset(Catch2002, CatchCategory=="Landings"|CatchCategory=="BMS landing")
Lan2002$CatchCategory <- factor(Lan2002$CatchCategory)

landCountry <- ddply(Lan2002,.(Country,Year),summarize,OfficialLand=sum(OfficialLandings[!is.na(OfficialLandings)]/1000), Caton=sum(Caton[!is.na(Caton)])/1000) 
landCountry <- ddply(Lan2002,.(Year, Country),summarize,Catch=sum(Caton[!is.na(Caton)])/1000) 

table1 <- cast(landCountry, Year~Country)

if(!"Spain" %in% colnames(table1)){table1$Spain = 0}

# Landings total by year -------------------------------------------------------
landbyyr <- ddply(Lan2002,.(Year),summarize,OfficialLand=sum(OfficialLandings[!is.na(OfficialLandings)]/1000), Caton=sum(Caton[!is.na(Caton)])/1000) 

# Landings by ICES Division ----------------------------------------------------
landDivA <- ddply(Lan2002,.(Year,Area, Country),summarize,Landings=sum(Caton)/1000) 
landDivb <- ddply(Lan2002,.(Year,Area),summarize,Landings=sum(Caton)/1000) 
Land_div2 <-reshape(landDivb,direction="wide",idvar="Year", timevar="Area")

# Landings by metier -----------------------------------------------------------
metier <- ddply(Lan2002,.(Year,metier2),summarize,Landings=sum(Caton)/1000)

# Landings by quarter ----------------------------------------------------------
LandQuarter1 <- ddply(Lan2002,.(Year,Season, Country),summarize,Landings=sum(Caton)/1000) 

# this is used in the spict model
LandQuarter2 <- ddply(Lan2002,.(Year,Season),summarize,landings=sum(Caton)/1000) 
LandQuarter2 <- dplyr::rename(LandQuarter2,Quarter=Season) #rename for model to work

#save catch input file for assessment
write.taf(LandQuarter2,paste0(wdir,"/data/Quarterly_landings_timeseries.csv"),quote=TRUE)

# Save processed data ----------------------------------------------------------
print("data stuff done, now try and save it all as rdata file...")
save.image(paste0(wdir,"/boot/data/processed_data_various.RData"))
print("This line should show if data.r ran succesfully")


# Extra section here to create table 6 from "Catches" --------------------------
latest_by_metier=metier[metier$Year==datayear,]
oth_class = latest_by_metier$Landings[latest_by_metier$metier2 %in%c("Other")]
pel_trawl_class = latest_by_metier$Landings[latest_by_metier$metier2 %in% c("OTM_SPF_16-31_0_0","OTM_SPF_32-69_0_0_all","OTB_SPF_32-69_0_0_all","PTM_SPF_16-31_0_0_all","PTM_SPF_32-69_0_0_all", "OTM_SPF_70-99_0_0_all", "OTB_SPF_70-99_0_0_all", "Pelagic trawl")]
ps_class = latest_by_metier$Landings[latest_by_metier$metier2 %in% c("PS_SPF_0_0_0")]

# As far as I can tell, this must have been how they were defined
purse_seine_perc = round((sum(ps_class)/landingssum)*100)
pelagic_trawl_perc = round((sum(pel_trawl_class)/landingssum)*100)
other_perc = round((sum(oth_class)/landingssum)*100)

save(list=c("landingssum","purse_seine_perc","pelagic_trawl_perc","other_perc"), file='boot/data/catches_by_category_table6.rdata')


# section here aims to create table 7 ------------------------------------------
# Aggregate landings
t7 <- landCountry %>%  pivot_wider(names_from = Country, values_from = Catch)

# Add spain if absent
if(!"Spain" %in% colnames(t7)){t7$Spain = 0}

# Add Eng and scotland together
t7["United.Kingdom"] = t7["UK (England)"] +  t7["UK(Scotland)"]
t7["UK (England)"] <- NULL
t7["UK(Scotland)"] <- NULL

# Should be dataframe not tibble
t7 = as.data.frame(t7)

# Order columns to be like old table
official_landings_7 = read.csv("boot/initial/data/official_landings_7.csv", fileEncoding = 'UTF-8-BOM',colClasses="character", stringsAsFactors=FALSE, na.strings=".")
t7 = t7[colnames(official_landings_7)]

# NA to 0
t7[is.na(t7)] = 0

# Add new catch rows on to the old table. This will go into the report
t7=rbind(official_landings_7,t7[t7$Year>2021,])
t7 = dplyr::mutate_all(t7, function(x) round(as.numeric(as.character(x))))
write.taf(t7,"boot/data/official_landings_7.csv")

