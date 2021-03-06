#######################################################
# Create manifest for MD Anderson samples (n = 120, GLASS)
# Date: 2018.09.28
# Author: Kevin J.
#######################################################
# Local directory for github repo.
mybasedir = "/Users/johnsk/Documents/Life-History/GLASS-WG"
setwd(mybasedir)

# Files with information about fastq information and barcodes.
life_history_barcodes = "data/ref/glass_wg_aliquots_mapping_table.txt"
life_history_filesize = "data/ref/mdacc_filesize.txt"
life_history_md5 = "data/ref/mdacc_md5.txt"
MDA_batch1_file_path = "data/sequencing-information/MDACC/file_list_C202SC18030593_batch1_n14_20180405.tsv"
MDA_batch2_file_path = "data/sequencing-information/MDACC/file_list_C202SC18030593_batch2_n94_20180603.tsv"
MDA_batch3_file_path = "data/sequencing-information/MDACC/file_list_C202SC18030593_batch2_n13_20180716.tsv"
MDA_batch4_file_path = "data/sequencing-information/MDACC/file_list_C202SC18030593_batch3_n13_20180816.tsv"
mda_clinical_info = "data/clinical-data/MDACC/MDA-Clinical-Dataset/Protocol_Surgery_39_final.20180821.xlsx"

# Clinical dataset priovided by Kristin Alfaro-Munoz at MD Anderson.
# Modified to generate a sample_type (TP, R1, R2, R3) using the clinical information. See github issue #16.
mda_master_path = "data/clinical-data/MDACC/MDA-Clinical-Dataset/Master Log for WGS_sampletype.20180630.xlsx"

# 2018.07.06 Katie Shao (Novogene) provided the following sheet linking libraryID with submitted sample names in the email:
# "Re:RE: Novogene Project Report - Confirm -C202SC18030593-Davis-MDACC-156-libseq-hWGS-WOBI-NVUS2018022505[J1-C202SC18030593-1000]"
novogene_sample_path = "data/sequencing-information/MDACC/Novogene_SIF_14.xlsx"

#######################################################

library(tidyverse)
library(openxlsx)
library(rjson)
library(jsonlite)
library(listviewer)
library(stringi)
library(stringr)
library(lubridate)
library(DBI)

#######################################################
# Establish connection.
con <- DBI::dbConnect(odbc::odbc(), "VerhaakDB")

# We need to generate the following fields required by the SNV snakemake pipeline:
# aliquots, files, cases, samples, pairs, and readgroups.

### MDA (Novogene cohort) barcode (re)generation ####
# Novogene has processed 120 samples. In our master sheet normal blood samples were not provided. We need them for barcodes.
# Inspect both batch1/batch2/batch3 sequencing data for all blood/tumor data.
mda_batch1_df <- read.table(MDA_batch1_file_path, col.names="relative_file_path", stringsAsFactors = F)
mda_batch1_df$file_name = sapply(strsplit(mda_batch1_df$relative_file_path, "/"), "[[", 3)
mda_batch2_df <- read.table(MDA_batch2_file_path, col.names="relative_file_path", stringsAsFactors = F)
mda_batch2_df$file_name = sapply(strsplit(mda_batch2_df$relative_file_path, "/"), "[[", 3)
mda_batch3_df <- read.table(MDA_batch3_file_path, col.names="relative_file_path", stringsAsFactors = F)
mda_batch3_df$file_name = sapply(strsplit(mda_batch3_df$relative_file_path, "/"), "[[", 3)
mda_batch4_df <- read.table(MDA_batch4_file_path, col.names="relative_file_path", stringsAsFactors = F)
mda_batch4_df$file_name = sapply(strsplit(mda_batch4_df$relative_file_path, "/"), "[[", 3)

# Replace the placeholder for pwd "./" from bash cmd: "find -name ".fq.gz" in parent directory of fastqs. 
mda_batch1_df$working_file_path <- gsub("^", "/fastscratch/GLASS-WG/data/mdacc", mda_batch1_df$relative_file_path)
mda_batch2_df$working_file_path <- gsub("^", "/fastscratch/GLASS-WG/data/mdacc/C202SC18030593_batch1_n94_20180603", mda_batch2_df$relative_file_path)
mda_batch3_df$working_file_path <- gsub("^", "/fastscratch/GLASS-WG/data/mdacc/C202SC18030593_batch2_n13_20180716", mda_batch3_df$relative_file_path)
mda_batch4_df$working_file_path <- gsub("^", "/fastscratch/GLASS-WG/data/mdacc/DT20180816", mda_batch4_df$relative_file_path)


# Create an old sample.id for these subjects to be linked. No longer *necessary*, but kept in case it's helpful.
mda_batch1_df$old_sample_id <- gsub( "_USPD.*$", "", mda_batch1_df$file_name)
mda_batch2_df$old_sample_id <- gsub( "_USPD.*$", "", mda_batch2_df$file_name)
mda_batch3_df$old_sample_id <- gsub( "_USPD.*$", "", mda_batch3_df$file_name)
mda_batch4_df$old_sample_id <- gsub( "_USPD.*$", "", mda_batch4_df$file_name)

# Combine these three sequencing data sets. There should be 604 files.
mda_df <- bind_rows(mda_batch1_df, mda_batch2_df, mda_batch3_df, mda_batch4_df)

# Combine these three sequencing data sets. There should be 604 files.
mda_df <- bind_rows(mda_batch1_df, mda_batch2_df, mda_batch3_df, mda_batch4_df)

# Katie Shao (Novogene provided).
novogene_linker = readWorkbook(novogene_sample_path, sheet = 1, startRow = 18, colNames = TRUE)
novogene_linker_unique <- novogene_linker[1:121, ] # 121st sample represents non-GLASS sample.

# Retrieve only the blood samples ("10D"). Blood samples not presented in master sheet.
normal_blood_samples = novogene_linker_unique[grep("[b|B]lood", novogene_linker_unique$`*SampleName`), ]

# Retrieve the subject ID in same format as tumor samples.
normal_blood_samples$SubjectID = sapply(strsplit(normal_blood_samples$`*SampleName`, "-"), "[", 3)

# Create a barcode for available blood samples (n=39).
mda_normal_blood_map <- normal_blood_samples %>% 
  mutate(SeqID = "GLSS") %>% 
  mutate(TSS = "MD") %>% 
  dplyr::rename(SubjectCode = SubjectID) %>% 
  mutate(TissueCode = "NB") %>% 
  mutate(Original_ID = `*SampleName`) %>%   
  unite(Barcode, c(SeqID, TSS, SubjectCode, TissueCode), sep = "-", remove = FALSE) %>% 
  select(Original_ID, Barcode, SeqID, TSS, SubjectCode, TissueCode) %>% 
  distinct()
  
### Use master sheet containing tumor sample information, necessary to build barcodes.####
# Kristin Alfaro-Munoz kindly pointed me to the sequencing identifier link to these samples. 
mda_master = readWorkbook(mda_master_path, sheet = 2, startRow = 1, colNames = TRUE)

# The master sheet from MDA only contains tumor samples. Sum should equal 81 (tumor samples).
sum(novogene_linker_unique$'*SampleName'%in%mda_master$Jax.Lib.Prep.Customer.Sample.Name)

# Extract the 4-digit SUBJECT identifier.
mda_master$SubjectID = sapply(strsplit(mda_master$Jax.Lib.Prep.Customer.Sample.Name, "-"), "[", 3)

# Map the old to new sample name for the tumors.
mda_tumor_sample_map = mda_master[1:81,] %>% 
  mutate(SeqID = "GLSS") %>% 
  mutate(TSS = "MD") %>% 
  rename(SubjectCode = SubjectID) %>% 
  rename(TissueCode = sample_type) %>% 
  mutate(Original_ID = Jax.Lib.Prep.Customer.Sample.Name) %>% 
  unite(Barcode, c(SeqID, TSS, SubjectCode, TissueCode), sep = "-", remove = FALSE) %>% 
  select(Original_ID, Barcode, SeqID, TSS, SubjectCode, TissueCode)

# Combine all tumor and normal samples together. Should equal 120 for this GLASS dataset.
mda_all_samples_df <- bind_rows(mda_normal_blood_map, mda_tumor_sample_map)


### Aliquot ####
life_history_ids = read.delim(life_history_barcodes, as.is=T)
aliquots_master = life_history_ids %>% mutate(aliquot_barcode = aliquot_id,
                                              sample_barcode = substr(aliquot_barcode, 1, 15),
                                              sample_type = substr(aliquot_barcode, 14, 15),
                                              case_barcode = substr(aliquot_barcode, 1, 12),
                                              aliquot_uuid_short = substr(aliquot_barcode, 25, 30),
                                              aliquot_analyte_type = substr(aliquot_barcode, 19, 19),
                                              aliquot_portion = substr(aliquot_barcode, 17, 18),
                                              aliquot_analysis_type = substr(aliquot_barcode, 21, 23),
                                              aliquot_id_legacy = legacy_aliquot_id) %>%
  select(-legacy_aliquot_id) %>% 
  filter(grepl("GLSS-MD", sample_barcode)) %>% 
  filter(!grepl("GLSS-MD-LP", sample_barcode))

### aliquots
aliquots = aliquots_master %>% 
  select(aliquot_barcode, aliquot_id_legacy, sample_barcode, aliquot_uuid_short,
         aliquot_analyte_type, aliquot_analysis_type, aliquot_portion) %>% 
  distinct()


### Files ####
# Generate *file* tsv containing: aliquot_id, file_path, file_name, file_uuid, file_size, file_md5sum, file_format.
# From above ^: mda_df = bind_rows(mda_batch1_df, mda_batch2_df, mda_batch3_df, mda_batch4_df)
mda_filesize = read_tsv(life_history_filesize, col_names=c("file_size", "file_name"))
mda_md5 = read_tsv(life_history_md5, col_names=c("file_md5sum", "file_name"))

# Retrieve the library, flowcell, and lane id from the filename.
mda_df_meta  = mda_df %>% 
  mutate(library_id = sub(".*_ *(.*?) *_H.*", "\\1", file_name), 
         flowcell_id = substr(file_name, nchar(file_name)-19, nchar(file_name)-12),
         lane_id = substr(file_name, nchar(file_name)-8, nchar(file_name)-8)) %>% 
  inner_join(mda_md5, by="file_name") %>% 
  inner_join(mda_filesize, by="file_name") 


# Create a new identifier on which to group mate pairs onto the same line (i.e., R1 and R2).
mda_df_meta$read_group = paste(mda_df_meta$library_id, mda_df_meta$flowcell_id, mda_df_meta$lane_id, sep = '-')

# Comma separated file_paths and file_names. "L#_1" and "L#_2" can be any order. Doesn't yet matter for Snakemake.
#merged_mda_files = mda_df_meta %>% 
#  select(-relative_file_path) %>% 
#  group_by(read_group) %>% 
#  mutate(file_path = paste(working_file_path, collapse=","), 
#         file_name = paste(filename, collapse=",")) %>% 
#  select(-filename, -working_file_path) %>% 
#  distinct()

# Not all of the samples are separated by the same characters. Revise for consistency.
# 1. Fixing  "G01_" >> GLASS_01_00".
mda_df_meta$revised_id <- gsub("G01_", "GLASS_01_00", mda_df_meta$old_sample_id)

# Combine with the new files with the sample name provided by Novogene.
# This action will remove the Yung sample.
mda_map_df = mda_df_meta %>% 
  mutate(file_format = "FASTQ") %>% 
  inner_join(novogene_linker_unique, by = c("library_id" = "Novogene.ID")) %>%  
  inner_join(aliquots_master, by = c("*SampleName" = "aliquot_id_legacy")) 


# We noticed that several fastq files are empty causing errors in Snakemake.
empty_fastqs <- read.table("data/sequencing-information/MDACC/empty_fastqs_to_remove_from_json.txt", stringsAsFactors = F, skip = 1)
empty_fastqs$fastqname <- sapply(strsplit(empty_fastqs$V1, "/"), "[[", 3)
empty_fastqs$read_group <- substr(empty_fastqs$fastqname, nchar(empty_fastqs$fastqname)-32, nchar(empty_fastqs$fastqname)-8)

# Stitched the files together as was done for the rest of the dataset.
files_to_remove = empty_fastqs %>% 
  mutate(file_name = fastqname) %>% 
  select(-V1, -fastqname) %>% 
  distinct()

# Since, the order of the paired fastqs was not ordered I needed to use either forward or reverse orientation.
rows_to_remove <- which(mda_map_df$file_name%in%files_to_remove$file_name==TRUE)

# Remove the empty files. Should be 296 at this point.
mda_map_df <- mda_map_df[-rows_to_remove, ]

# Need to record the file_size and file_md5sum for these samples.
files = mda_map_df %>% 
  select(aliquot_barcode, file_name, file_size, file_md5sum, file_format) %>%
  distinct()


### Cases ####
# Clinical data to extract subject sex.
mda_clinical_data <- readWorkbook(mda_clinical_info, sheet = 1, startRow = 1, colNames = TRUE)

# Create an Age at Diagnosis variable from birthdate to date of first surgery.
mda_clinical <- mda_clinical_data %>% 
  distinct(MRN, .keep_all = TRUE) %>% 
  mutate(Birth.Date = convertToDate(Birth.Date),
         Surgery.Date = convertToDate(Surgery.Date),
         Age.At.Diagnosis = as.numeric(difftime(Surgery.Date, Birth.Date, units = "weeks")/52))

# Select only those relevant fields.
cases = mda_clinical %>% 
  mutate(age = floor(Age.At.Diagnosis),
         sex = recode(Gender, "Male"="male", "Female"="female")) %>% 
  inner_join(mda_master, by ="MRN") %>% 
  inner_join(mda_map_df, by= c("Jax.Lib.Prep.Customer.Sample.Name"="*SampleName")) %>% 
  mutate(case_id = substring(aliquot_id, 1, 12), 
         case_project = "GLSS",
         case_source = substr(aliquot_id,6,7)) %>% 
  distinct(MRN, .keep_all = T) %>% 
  select(case_project, case_barcode, case_source, case_age_diagnosis_years=age, case_sex=sex) %>% 
  distinct()




### Samples ####
# Grab last two characrters of barcode.
mda_map_df$sample_type = substring(mda_map_df$aliquot_id, 14, 15)

# Recode variables to match Floris' fields.
samples = mda_map_df %>% 
  select(case_barcode, sample_barcode, sample_type) %>% 
  distinct()



### Readgroups ####
# Necessary information: file_uuid, aliquot_id, RGID, RGPL, RGPU, RGLB, RGPI, RGDT, RGSM, RGCN.
readgroup_df = mda_map_df %>% 
  mutate(readgroup_platform = "ILLUMINA",
       readgroup_platform_unit = paste(substr(file_name, nchar(file_name)-19, nchar(file_name)-11), 
                                       substr(file_name, nchar(file_name)-8, nchar(file_name)-8), sep="."),
       readgroup_library = sub(".*_ *(.*?) *_H.*", "\\1", file_name),
       readgroup_date = strftime(as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%dT%H:%M:%S%z"), 
       readgroup_sample_id = aliquot_id,
       readgroup_center = "NVGN_MD",
       readgroup_id = paste0(substring(readgroup_platform_unit, 1, 5), substring(readgroup_platform_unit, nchar(readgroup_platform_unit)-1, nchar(readgroup_platform_unit)), "")) 

# Finalize readgroup information in predefined order.
readgroups = readgroup_df %>% 
  select(aliquot_barcode, readgroup_idtag=readgroup_id, readgroup_platform, readgroup_platform_unit, readgroup_library,
         readgroup_center) %>% 
  mutate(readgroup_sample_id = aliquot_barcode) %>% distinct()

## Filemap
files_readgroups = mda_map_df %>% 
  mutate(readgroup_idtag = paste(substring(mda_map_df$flowcell_id, 1, 5), mda_map_df$lane_id, sep = "."), 
         readgroup_sample_id = aliquot_barcode) %>% 
  select(file_name, readgroup_idtag, readgroup_sample_id)

### OUTPUT ####
## Write to database.
dbWriteTable(con, Id(schema="clinical",table="cases"), cases, append=T)
dbWriteTable(con, Id(schema="biospecimen",table="samples"), samples, append=T)
dbWriteTable(con, Id(schema="biospecimen",table="aliquots"), aliquots, append=T)
dbWriteTable(con, Id(schema="biospecimen",table="readgroups"), readgroups, append=T)
dbWriteTable(con, Id(schema="analysis",table="files"), files, append=T)
dbWriteTable(con, Id(schema="analysis",table="files_readgroups"), files_readgroups, append=T)






