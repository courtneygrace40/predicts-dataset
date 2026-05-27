library(readr)
library(tidyverse)
library(dplyr)
library(vegan)
library(flexclust)
library(janitor)
library(factoextra)
library(cluster)
library(fastDummies)
library(dplyr)
library(caret)
library(randomForest)
library(openintro)
library(tidyverse)
library(caret)
library(pROC)
library(rpart)
library(rpart.plot)
library(caret)
library(e1071)
library(caTools)
library(caret)
library(tidyr)
library(flextable)

#Gemini, class notes/R scripts/etc were used to help create the code for this script
# (I relied primarily on class notes, but there were definitely some difficult/tricky things I wanted to do 
# with my data that I needed help with)

PREDICT <- read_csv("PREDICT.csv")

predict <- PREDICT %>%
  mutate(across(where(is.character), as.factor))

#Initial cleaning, axing variables that are irrelevant and/or text, filtering for NA values, creating year and month columns
predicts <- predict %>%
  select(-Reference, -Measurement, 
         -Taxon_name_entered, -Habitat_as_described, 
         -Name_status, -Parsed_name, -Taxon_number,
         -Source_for_predominant_habitat, -Source_for_predominant_land_use, 
         -"_id",  -COL_ID, -Block, -Coordinates_method, -Transect_details, -Wilderness_area,
         -Habitat_patch_area_square_metres, -Km_to_nearest_edge_of_habitat,
         -Max_linear_extent, -Predominant_habitat, -Country_distance_metres, 
         -Hotspot, -Years_since_fragmentation_or_conversion, -Species, -Site_name, -Site_number, -Source_ID,
         -Max_linear_extent_metres, -Indication, -Genus, -SS,
         -Ecoregion_distance_metres, -Eco_region_distance_metres, -Sample_end_latest, -Sample_start_earliest,
         -SSB, -SSS, -Study_name, -Study_number, -Diversity_metric_unit) %>%
  filter(Predominant_land_use != "Cannot decide") %>%
  filter(!is.na(Sampling_effort)) %>%
  filter(!is.na(Best_guess_binomial) & !is.na(Family))  %>%
  mutate(
    Year = year(as_date(Sample_midpoint)),
    Month = month(as_date(Sample_midpoint))
  )

# ---- STATISTIC CREATION ---- 
predicts_2 <- predicts %>%
  filter(Diversity_metric_type == "Abundance") %>%
  group_by(SSBS) %>% #filtering by site, etc the most restrictive label 
  mutate(
    Site_Total_Abundance = sum(Effort_corrected_measurement, na.rm = TRUE),
    Site_Species_Richness = n_distinct(Best_guess_binomial[Effort_corrected_measurement > 0]),
    i = Effort_corrected_measurement / Site_Total_Abundance,
    Site_Shannon_Index = -sum(i[i > 0] * log(i[i> 0])),
    Site_Simpson_Index = 1 - sum(i^2),
    Site_Evenness = Site_Shannon_Index / log(Site_Species_Richness)
  ) %>%
  select(-i, -Diversity_metric_type) %>%
  mutate(across(starts_with("Site_"), ~replace_na(., 0))) %>%
  ungroup()

predicts_nn <- predicts_2 %>%
  select( -SSBS, -Sample_midpoint, -Phylum, -Diversity_metric, -UN_region, -Site_Evenness)

# ---- NORMALIZATION ---- 
normalize <- function(x){(x-min(x))/(max(x)-min(x))}
predicts_nn_test <- predicts_nn %>%
  mutate(Is_present = case_when(
    Effort_corrected_measurement == 0 ~ 0,
    TRUE ~1
    ), 
  Effort_corrected_measurement = log1p(Effort_corrected_measurement), 
  Year = scale(Year), 
  Effort_corrected_measurement = scale(Effort_corrected_measurement),
  Longitude = scale(Longitude),
  Latitude = scale(Latitude), 
  Diversity_metric_is_effort_sensitive = ifelse(as.logical(Diversity_metric_is_effort_sensitive), 1, 0),
  Diversity_metric_is_suitable_for_Chao = ifelse(as.logical(Diversity_metric_is_suitable_for_Chao), 1, 0),
  )

#to prevent crashing, using the four variables that measure site health to understand how they grou
#different sites together 
set.seed(247324)
predicts_nn_kmeans <- predicts_nn_test %>%
  sample_n(40000) %>%
  select(Site_Shannon_Index, Site_Simpson_Index, Site_Total_Abundance, Site_Species_Richness)%>%
  scale()


#the plot of the clusters
km_plot <- kmeans(predicts_nn_kmeans, centers = 4, nstart = 25)
fviz_cluster(km_plot, data = predicts_nn_kmeans,
             geom = "point",
             ellipse.type = "convex", 
             palette = "aaas",
             main = "Ecological Health Clusters (Subsampled n=40000)",
             ggtheme = theme_minimal())

# Map full data to the centroids found in the sample
km_kcca <- as.kcca(km_plot, predicts_nn_kmeans)
full_data_to_cluster <- predicts_nn_test %>% 
  select(Site_Shannon_Index, Site_Simpson_Index, Site_Total_Abundance, Site_Species_Richness) %>% 
  scale()

predicts_nn_test$Health_Status <- as.factor(predict(km_kcca, newdata = full_data_to_cluster))
target_vars <- c("Site_Shannon_Index", "Site_Simpson_Index", "Site_Total_Abundance", "Site_Species_Richness")

train_matrix <- predicts_nn_test %>%
  sample_n(40000) %>%
  select(all_of(target_vars)) %>%
  scale() %>%
  as.matrix()

km_res <- kmeans(train_matrix, centers = 4, nstart = 25)
km_kcca <- as.kcca(km_res, train_matrix)

test_matrix <- predicts_nn_test %>%
  select(all_of(target_vars)) %>%
  scale() %>%
  as.matrix()

predicts_nn_test$Health_Status <- as.factor(predict(km_kcca, newdata = test_matrix))


summary(predicts_nn_test$Health_Status)
predicts_for_summary <- predicts_nn_test
summary(predicts_for_summary$health_status)
predicts_nn_test <- predicts_nn_test %>%
  filter(Health_Status != "4")

#--- QUICK WAY TO MAKE DUMMY COLUMNS ---

predicts_final_nn <- predicts_nn_test %>%
  dummy_cols(
    select_columns = c("Predominant_land_use", "Use_intensity", "Sampling_method"),
    remove_first_dummy = TRUE,     
    remove_selected_columns = TRUE   
  )

# --- CLEANS NAMES ---
predicts_final_nn <- clean_names(predicts_final_nn)
predicts_for_summary <- clean_names(predicts_for_summary)
predicts_final_nn$sampling_effort_unit <- as.factor(predicts_final_nn$sampling_effort_unit)

#--- SUMMARY OF ATTRIBUTES ---
predicts_summary <- predicts_for_summary %>%
  group_by(health_status)%>%
  summarize(
    avg_shannon = mean(site_shannon_index), 
    avg_simpson = mean(site_simpson_index),
    avg_abundance = mean(site_total_abundance),
    avg_richness = mean(site_species_richness))

#Some had too many unique attributes 
predicts_rf <- predicts_final_nn %>%
  select(where(~ !is.character(.) && !is.factor(.)) | # Keep numeric/logical
           where(~ (is.character(.) | is.factor(.)) && n_distinct(.) <= 53)) %>%
  select(-latitude, -longitude, -year, -month, -higher_taxon, -sampling_effort, -sample_date_resolution, -study_common_taxon, -rank_of_study_common_taxon,
         -rescaled_sampling_effort, -sampling_effort_unit, -site_shannon_index, -class, -kingdom, -rank, -site_simpson_index, -site_species_richness, -site_total_abundance)

summary(predicts_rf$health_status)

#---DEALING WITH HEALTH STATUS---

predicts_rf$health_status <- factor(
  predicts_rf$health_status,
  levels = c(1, 2, 3), # Define the three valid levels you want to keep
  #labels = c("Transitional", "Healthy", "Degraded") # Assign descriptive labels
)


levels(predicts_rf$health_status)

set.seed(123)
train.index <- createDataPartition(
  predicts_rf$health_status, 
  p = 0.70, 
  list = FALSE, 
  times = 1
)

summary(predicts_rf$health_status)
train_predicts <- predicts_rf[train.index,]
test_predicts <- predicts_rf[-train.index,]

# ---- BALANCING DATA ---- 
x <- train_predicts %>% 
  select(-health_status)
y <- train_predicts$health_status

balanced_list <- downSample(x = x, y = y)
balanced_list <- balanced_list %>%
  rename(health_status = Class)

# ---- NAIVE BAYES ---- 
classifier_cl <- naiveBayes(health_status ~ ., data = balanced_list)
y_pred <- predict(classifier_cl, newdata = test_predicts)

cm <- table(y_pred, test_predicts$health_status)
confusionMatrix(cm)

table(balanced_list$health_status)

# ---- RANDOM FOREST ----
set.seed(233)
rf_model <- randomForest(health_status ~ ., data = balanced_list, ntree = 100, importance = TRUE)
varImpPlot(rf_model, type = 1, main = "The Features")


oob.error.data_w <-data.frame(
  Trees=rep(1:nrow(rf_model$err.rate),times=3),
  Type = rep(c("Overall OOB", "Degraded", "Not Degraded"), each = nrow(rf_model$err.rate)),
  Error = c(
    rf_model$err.rate[, "OOB"],
    rf_model$err.rate[, "Degraded"],
    # For Transitional/Healthy combined, you can take the mean of the other two or target just one:
    (rf_model$err.rate[, "Healthy"] + rf_model$err.rate[, "Transitional"]) / 2
  )
  )

set.seed(3294)
three_class_weights <- c(1.0, 1.0, 10.0) 

rf_model_tuned <- randomForest(
  health_status ~ ., 
  data = balanced_list,
  ntree = 100, # Can increase this if needed
  importance = TRUE
)
varImpPlot(rf_model_tuned, type = 1, main = "The Features")

library(ggplot2)

ggplot(data = oob.error.data_w, aes(x = Trees, y = Error, color = Type)) +
  geom_line(size = 1) +
  scale_color_manual(values = c("Overall OOB" = "black", 
                                "Degraded" = "red", 
                                "Not Degraded" = "blue")) +
  labs(title = "Random Forest Error Rates: Degraded vs. Other Classes",
       x = "Number of Trees",
       y = "Error Rate",
       color = "Category") +
  theme_minimal()

predicted_test <- predict(rf_model_tuned, newdata=test_predicts, type="response")
predicted_prob_test <- predict(rf_model_tuned, newdata=test_predicts, type="prob")
ROC<- roc(test_predicts$health_status~predicted_prob_test[,2], plot=TRUE,legacy.axes=T)
auc(ROC)

test_pred <- predict(rf_model, newdata = test_predicts)
conf_matrix <- confusionMatrix(predicted_test, test_predicts$health_status)


ft <- flextable(predicts_summary)
ft <- add_header_row(
  ft,
  colwidths = c(1, 4),
  values = c("Health Status", "Averages")
)
ft <- fontsize(ft, size = 11, part = "header")
ft <- bold(ft, part = "header")
ft <- theme_vanilla(ft)
ft <- add_footer_lines(ft, "Source: PREDICTS Database")
ft <- color(ft, part = "footer", color = "#666666")
ft <- set_caption(ft, caption = "Distribution of Site Health Measurements Across Health Status Levels")

ft

ggplot(predicts_final_nn, aes(x = factor(health_status), y = site_total_abundance)) +
  geom_boxplot(fill = "white", color = "black", outlier.shape = 1) +
  theme_bw() +
  labs(
    title = "Site Abundance Across Health Status Levels",
    x = "Health Status",
    y = "Site Abundance"
  )

save_as_image(ft, path = "predicts_summary_2.png", zoom = 2, expand = 5)

cm_table <- as.data.frame(conf_matrix$table)
cm_wide <- pivot_wider(cm_table, names_from = Reference, values_from = Freq)

# ---- TABLE FOR PRESENTATION ----
ft <- flextable(cm_wide)
ft <- theme_booktabs(ft)
ft <- set_header_labels(ft, 
                        Prediction = "Prediction", 
                        `1` = "Transitional", 
                        `2` = "Healthy", 
                        `3` = "Degraded")
ft <- add_header_row(ft, colwidths = c(1, 3), values = c("", "Reference"))
ft <- align(ft, align = "center", part = "all")
ft <- bg(ft, bg = "transparent", part = "all")
ft <- fontsize(ft, size = 10, part = "all")
ft


write.csv(predicts_rf, file = "predicts_nn.csv", row.names = FALSE)
library(officer)
library(flextable)
# 1. Create a blank Word document layout
doc <- read_docx()

# 2. Add your flextable directly to the layout object
doc <- body_add_flextable(doc, value = ft)

# 3. Save the document to your local directory
print(doc, target = "ecological_summary_table.docx")




