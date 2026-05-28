# Predicting the Health Status of Ecological Sites Using Machine Learning Methods
## Project Overview 
This is an end-to-end data pipeline using the PREDICTS dataset, which contains over 1,000,000 observations. The goal of these models is to classify sites as Healthy, Transitional, or Degraded using the attributes recorded in this study. By classifying sites, this model can help scientists identify when and why sites become degraded to intervene sooner to restore ecological diversity.  

[View Full Technical Report (PDF)](Predicting_the_Health_Status_of_Ecological_Sites_Using_Machine_Learning_Methods.pdf)

## Key Accomplishments & Metrics
- Massive Scale Data Pipeline: Sanitized and transformed a high-dimensional dataset with 72 attributes. Handled missing data mechanisms (MCAR vs. MNAR), engineered log-transforms for highly skewed metrics, and filtered outliers through statistical profiling.  
- Unsupervised Taxonomy Design: Built a K-Means clustering algorithm using principal component dimensions (explaining 85.5% of total variance) to objectively establish health baseline profiles using Shannon and Simpson diversity indices.  
- Advanced Feature Engineering: Avoided sparse matrix issues for high-cardinality geographic attributes by mapping complex categories (e.g., countries, biomes) into low-dimensional word embeddings for deep learning ingestion.  
- Class Imbalance Resolution: Optimized model behavior against a heavily skewed majority class by introducing a hybrid strategy combining random majority undersampling and custom cross-entropy class weighting.  
- High-Performance Modeling: Outperformed a Naïve Bayes baseline ($31.3\%$ accuracy) by training a 3-layer Deep Neural Network yielding an overall accuracy of **82%** and a multi-class AUC of **0.9569**. 

### Class Breakdown
| Health Status Code | Profile Description | Avg. Shannon Index | Avg. Simpson Index | Avg. Abundance | Avg. Richness |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **1** | Degraded | 0.5239471 | 0.2911697 | 2,187.002 | 3.080601 |
| **2** | Healthy | 3.3346419 | 0.9414118 | 1,382.080 | 55.995928 |
| **3** | Transitional | 2.0014464 | 0.8132311 | 2,738.989 | 11.207040 |
| **4** | Outliers (Thrown out) | 1.9719159 | 0.7759321 | 47,194.956 | 14.571577 |

*Source: PREDICTS Database*

