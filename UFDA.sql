-- =====================================================
-- URBAN FOOD DESERT ANALYZER - MySQL Workbench Version
-- =====================================================

-- Create Database
CREATE DATABASE IF NOT EXISTS urban_food_desert_analyzer;
USE urban_food_desert_analyzer;

-- Enable spatial functions
SET sql_mode = '';

-- =====================================================
-- DATABASE SCHEMA CREATION
-- =====================================================

-- Geographic areas (census tracts, neighborhoods)
CREATE TABLE geographic_areas (
    area_id INT AUTO_INCREMENT PRIMARY KEY,
    tract_id VARCHAR(20) UNIQUE NOT NULL,
    area_name VARCHAR(100),
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    boundary_coordinates JSON,  -- Store polygon coordinates as JSON
    total_population INT,
    median_household_income DECIMAL(10,2),
    poverty_rate DECIMAL(5,2),
    vehicle_ownership_rate DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_tract_id (tract_id),
    INDEX idx_coordinates (latitude, longitude)
);

-- Food retailers (grocery stores, supermarkets, etc.)
CREATE TABLE food_retailers (
    retailer_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    retailer_type ENUM('supermarket', 'grocery', 'convenience', 'farmers_market', 'other') DEFAULT 'other',
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    store_size_sqft INT,
    fresh_produce_available BOOLEAN DEFAULT FALSE,
    accepts_snap BOOLEAN DEFAULT FALSE,
    operating_hours JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_location (latitude, longitude),
    INDEX idx_retailer_type (retailer_type),
    INDEX idx_produce_snap (fresh_produce_available, accepts_snap)
);

-- Food pricing data
CREATE TABLE food_prices (
    price_id INT AUTO_INCREMENT PRIMARY KEY,
    retailer_id INT,
    product_category ENUM('produce', 'dairy', 'meat', 'pantry', 'other') DEFAULT 'other',
    product_name VARCHAR(100),
    price_per_unit DECIMAL(8,2),
    unit_type VARCHAR(20), -- 'lb', 'gallon', 'each'
    collection_date DATE,
    nutritional_score INT CHECK (nutritional_score BETWEEN 1 AND 10),
    FOREIGN KEY (retailer_id) REFERENCES food_retailers(retailer_id) ON DELETE CASCADE,
    INDEX idx_retailer_date (retailer_id, collection_date),
    INDEX idx_category_score (product_category, nutritional_score)
);

-- Transportation network
CREATE TABLE public_transit (
    transit_id INT AUTO_INCREMENT PRIMARY KEY,
    stop_name VARCHAR(200),
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    transit_type ENUM('bus', 'subway', 'light_rail', 'other') DEFAULT 'other',
    routes JSON, -- Store route information as JSON array
    frequency_minutes INT,
    INDEX idx_transit_location (latitude, longitude),
    INDEX idx_transit_type (transit_type)
);

-- =====================================================
-- HELPER FUNCTIONS AND PROCEDURES
-- =====================================================

-- Function to calculate distance between two points using Haversine formula
DELIMITER //
CREATE FUNCTION calculate_distance_miles(
    lat1 DECIMAL(10,8), 
    lon1 DECIMAL(11,8), 
    lat2 DECIMAL(10,8), 
    lon2 DECIMAL(11,8)
) 
RETURNS DECIMAL(10,4)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE distance DECIMAL(10,4);
    DECLARE earth_radius DECIMAL(10,4) DEFAULT 3959; -- Earth radius in miles
    DECLARE dlat DECIMAL(10,8);
    DECLARE dlon DECIMAL(11,8);
    DECLARE a DECIMAL(20,10);
    DECLARE c DECIMAL(20,10);
    
    SET dlat = RADIANS(lat2 - lat1);
    SET dlon = RADIANS(lon2 - lon1);
    SET a = SIN(dlat/2) * SIN(dlat/2) + COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * SIN(dlon/2) * SIN(dlon/2);
    SET c = 2 * ASIN(SQRT(a));
    SET distance = earth_radius * c;
    
    RETURN distance;
END//
DELIMITER ;

-- =====================================================
-- SAMPLE DATA INSERT STATEMENTS
-- =====================================================

-- Insert sample geographic areas
INSERT INTO geographic_areas (tract_id, area_name, latitude, longitude, total_population, median_household_income, poverty_rate, vehicle_ownership_rate) VALUES
('06001400100', 'Downtown Oakland', 37.8044, -122.2711, 4500, 45000, 18.5, 0.65),
('06001400200', 'West Oakland', 37.8041, -122.2941, 3200, 38000, 22.3, 0.58),
('06001400300', 'East Oakland', 37.7849, -122.2364, 5800, 42000, 20.1, 0.62),
('06001400400', 'North Oakland', 37.8271, -122.2605, 4100, 52000, 15.2, 0.72),
('06001400500', 'South Oakland', 37.7749, -122.2194, 3900, 48000, 16.8, 0.69);

-- Insert sample food retailers
INSERT INTO food_retailers (name, retailer_type, latitude, longitude, address, fresh_produce_available, accepts_snap, store_size_sqft) VALUES
('SafeWay Downtown', 'supermarket', 37.8050, -122.2720, '123 Broadway St', TRUE, TRUE, 45000),
('Corner Market West', 'convenience', 37.8035, -122.2950, '456 7th St', FALSE, TRUE, 2500),
('Fresh & Easy East', 'grocery', 37.7855, -122.2370, '789 International Blvd', TRUE, TRUE, 15000),
('Whole Foods North', 'supermarket', 37.8280, -122.2610, '321 Grand Ave', TRUE, FALSE, 52000),
('Local Grocers South', 'grocery', 37.7755, -122.2200, '654 MacArthur Blvd', TRUE, TRUE, 8000),
('Quick Stop Market', 'convenience', 37.8000, -122.2500, '111 Telegraph Ave', FALSE, FALSE, 1200);

-- Insert sample food prices
INSERT INTO food_prices (retailer_id, product_category, product_name, price_per_unit, unit_type, collection_date, nutritional_score) VALUES
(1, 'produce', 'Bananas', 1.29, 'lb', CURDATE(), 8),
(1, 'produce', 'Apples', 2.49, 'lb', CURDATE(), 9),
(1, 'dairy', 'Milk (2%)', 3.89, 'gallon', CURDATE(), 7),
(1, 'meat', 'Ground Beef', 5.99, 'lb', CURDATE(), 5),
(2, 'produce', 'Bananas', 1.89, 'lb', CURDATE(), 8),
(2, 'pantry', 'White Bread', 2.99, 'each', CURDATE(), 4),
(3, 'produce', 'Mixed Greens', 3.49, 'each', CURDATE(), 9),
(3, 'dairy', 'Greek Yogurt', 1.25, 'each', CURDATE(), 8),
(4, 'produce', 'Organic Apples', 4.99, 'lb', CURDATE(), 10),
(4, 'meat', 'Organic Chicken', 12.99, 'lb', CURDATE(), 8),
(5, 'produce', 'Carrots', 1.79, 'lb', CURDATE(), 9),
(5, 'pantry', 'Brown Rice', 3.29, 'lb', CURDATE(), 7);

-- Insert sample transit stops
INSERT INTO public_transit (stop_name, latitude, longitude, transit_type, frequency_minutes) VALUES
('Downtown Transit Center', 37.8055, -122.2715, 'bus', 15),
('West Oakland BART', 37.8047, -122.2947, 'subway', 5),
('MacArthur BART', 37.8291, -122.2674, 'subway', 5),
('International Blvd Bus Stop', 37.7860, -122.2365, 'bus', 20),
('Grand Ave Bus Stop', 37.8275, -122.2605, 'bus', 12);

-- =====================================================
-- CORE ANALYSIS QUERIES
-- =====================================================

-- 1. Geographic Access Analysis
-- Identify areas with limited grocery store access within 1 mile
SELECT 
    'Geographic Access Analysis' as analysis_type;

WITH area_store_distances AS (
    SELECT 
        ga.area_id,
        ga.tract_id,
        ga.area_name,
        ga.total_population,
        ga.median_household_income,
        fr.retailer_id,
        fr.name as store_name,
        fr.retailer_type,
        calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) as distance_miles
    FROM geographic_areas ga
    CROSS JOIN food_retailers fr
    WHERE fr.retailer_type IN ('supermarket', 'grocery')
      AND fr.fresh_produce_available = TRUE
),
closest_stores AS (
    SELECT 
        area_id,
        tract_id,
        area_name,
        total_population,
        median_household_income,
        MIN(distance_miles) as closest_store_distance,
        COUNT(CASE WHEN distance_miles <= 1.0 THEN 1 END) as stores_within_1mile,
        COUNT(CASE WHEN distance_miles <= 0.5 THEN 1 END) as stores_within_halfmile
    FROM area_store_distances
    GROUP BY area_id, tract_id, area_name, total_population, median_household_income
)
SELECT 
    tract_id,
    area_name,
    total_population,
    ROUND(median_household_income, 0) as median_household_income,
    ROUND(closest_store_distance, 2) as closest_store_distance,
    stores_within_1mile,
    stores_within_halfmile,
    CASE 
        WHEN closest_store_distance > 1.0 AND median_household_income < 50000 THEN 'High Risk Food Desert'
        WHEN closest_store_distance > 0.5 AND stores_within_1mile < 2 THEN 'Moderate Risk Food Desert'
        WHEN stores_within_halfmile = 0 THEN 'Limited Access'
        ELSE 'Adequate Access'
    END as food_access_category,
    -- Calculate population-weighted access score
    ROUND(
        (stores_within_1mile * 0.4 + stores_within_halfmile * 0.6) * 
        (CASE WHEN median_household_income < 30000 THEN 0.7 ELSE 1.0 END), 2
    ) as access_score
FROM closest_stores
ORDER BY closest_store_distance DESC, total_population DESC;

-- =====================================================

-- 2. Affordability Analysis
-- Calculate food affordability index by comparing local prices to income
SELECT 
    'Affordability Analysis' as analysis_type;

WITH area_avg_prices AS (
    SELECT 
        ga.area_id,
        ga.tract_id,
        ga.area_name,
        ga.median_household_income,
        AVG(CASE WHEN fp.product_category = 'produce' THEN fp.price_per_unit END) as avg_produce_price,
        AVG(CASE WHEN fp.product_category = 'dairy' THEN fp.price_per_unit END) as avg_dairy_price,
        AVG(CASE WHEN fp.product_category = 'meat' THEN fp.price_per_unit END) as avg_meat_price,
        AVG(CASE WHEN fp.nutritional_score >= 7 THEN fp.price_per_unit END) as avg_healthy_food_price,
        AVG(CASE WHEN fp.nutritional_score <= 4 THEN fp.price_per_unit END) as avg_unhealthy_food_price
    FROM geographic_areas ga
    JOIN food_retailers fr ON calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
    JOIN food_prices fp ON fr.retailer_id = fp.retailer_id
    WHERE fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    GROUP BY ga.area_id, ga.tract_id, ga.area_name, ga.median_household_income
),
affordability_metrics AS (
    SELECT 
        tract_id,
        area_name,
        median_household_income,
        ROUND(avg_produce_price, 2) as avg_produce_price,
        ROUND(avg_healthy_food_price, 2) as avg_healthy_food_price,
        ROUND(avg_unhealthy_food_price, 2) as avg_unhealthy_food_price,
        -- Calculate monthly food budget (assume 15% of income)
        ROUND((median_household_income * 0.15 / 12), 2) as monthly_food_budget,
        -- Healthy vs unhealthy price ratio
        CASE 
            WHEN avg_unhealthy_food_price > 0 
            THEN ROUND(avg_healthy_food_price / avg_unhealthy_food_price, 2)
            ELSE NULL 
        END as healthy_unhealthy_price_ratio
    FROM area_avg_prices
)
SELECT 
    tract_id,
    area_name,
    ROUND(median_household_income, 0) as median_household_income,
    monthly_food_budget,
    avg_healthy_food_price,
    healthy_unhealthy_price_ratio,
    CASE 
        WHEN monthly_food_budget < (avg_healthy_food_price * 100) THEN 'Low Affordability'
        WHEN healthy_unhealthy_price_ratio > 1.5 THEN 'Healthy Food Premium'
        ELSE 'Adequate Affordability'
    END as affordability_status,
    -- Affordability score (0-100)
    LEAST(100, ROUND(
        (monthly_food_budget / NULLIF(avg_healthy_food_price * 80, 0)) * 
        (CASE WHEN healthy_unhealthy_price_ratio > 2 THEN 0.7 ELSE 1.0 END) * 100, 0
    )) as affordability_score
FROM affordability_metrics
ORDER BY affordability_score ASC;

-- =====================================================

-- 3. Transportation Impact Assessment
-- Analyze public transit accessibility to food retailers
SELECT 
    'Transportation Impact Assessment' as analysis_type;

WITH transit_food_access AS (
    SELECT 
        ga.area_id,
        ga.tract_id,
        ga.area_name,
        ga.vehicle_ownership_rate,
        -- Find nearby transit stops (within 0.5 mile)
        (SELECT COUNT(*) 
         FROM public_transit pt 
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, pt.latitude, pt.longitude) <= 0.5
        ) as transit_stops_nearby,
        -- Count accessible food retailers via transit
        (SELECT COUNT(DISTINCT fr.retailer_id)
         FROM food_retailers fr
         WHERE EXISTS (
             SELECT 1 
             FROM public_transit pt 
             WHERE calculate_distance_miles(ga.latitude, ga.longitude, pt.latitude, pt.longitude) <= 0.5
               AND calculate_distance_miles(pt.latitude, pt.longitude, fr.latitude, fr.longitude) <= 0.25
         )
         AND fr.retailer_type IN ('supermarket', 'grocery')
         AND fr.fresh_produce_available = TRUE
        ) as transit_accessible_stores
    FROM geographic_areas ga
),
transportation_scores AS (
    SELECT 
        *,
        CASE 
            WHEN vehicle_ownership_rate >= 0.8 THEN 'High Vehicle Access'
            WHEN transit_stops_nearby >= 3 AND transit_accessible_stores >= 2 THEN 'Good Transit Access'
            WHEN transit_stops_nearby >= 1 AND transit_accessible_stores >= 1 THEN 'Limited Transit Access'
            ELSE 'Poor Transportation Access'
        END as transportation_category,
        -- Transportation accessibility score
        ROUND(
            (vehicle_ownership_rate * 0.6) + 
            (LEAST(transit_stops_nearby / 5.0, 1.0) * 0.4) + 
            (LEAST(transit_accessible_stores / 3.0, 1.0) * 0.3), 2
        ) * 100 as transportation_score
    FROM transit_food_access
)
SELECT 
    tract_id,
    area_name,
    ROUND(vehicle_ownership_rate, 2) as vehicle_ownership_rate,
    transit_stops_nearby,
    transit_accessible_stores,
    transportation_category,
    ROUND(transportation_score, 0) as transportation_score
FROM transportation_scores
ORDER BY transportation_score ASC;

-- =====================================================

-- 4. Comprehensive Food Desert Score Calculation
-- Combines all factors into a single food access score
SELECT 
    'Comprehensive Food Desert Analysis' as analysis_type;

WITH comprehensive_analysis AS (
    SELECT 
        ga.area_id,
        ga.tract_id,
        ga.area_name,
        ga.total_population,
        ga.median_household_income,
        ga.poverty_rate,
        ga.vehicle_ownership_rate,
        
        -- Geographic access metrics
        (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude))
         FROM food_retailers fr 
         WHERE fr.retailer_type IN ('supermarket', 'grocery')
           AND fr.fresh_produce_available = TRUE
        ) as closest_grocery_miles,
        
        (SELECT COUNT(*)
         FROM food_retailers fr 
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
         AND fr.retailer_type IN ('supermarket', 'grocery')
         AND fr.fresh_produce_available = TRUE
        ) as groceries_within_1mile,
        
        -- Price accessibility
        (SELECT AVG(fp.price_per_unit)
         FROM food_retailers fr
         JOIN food_prices fp ON fr.retailer_id = fp.retailer_id
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
         AND fp.nutritional_score >= 7
         AND fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ) as avg_healthy_food_price,
        
        -- Transit access
        (SELECT COUNT(*)
         FROM public_transit pt 
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, pt.latitude, pt.longitude) <= 0.5
        ) as nearby_transit_stops
        
    FROM geographic_areas ga
),
scored_analysis AS (
    SELECT 
        *,
        -- Distance score (0-100, higher is better)
        CASE 
            WHEN closest_grocery_miles IS NULL THEN 0
            WHEN closest_grocery_miles <= 0.5 THEN 100
            WHEN closest_grocery_miles <= 1.0 THEN 75
            WHEN closest_grocery_miles <= 2.0 THEN 50
            ELSE 25
        END as distance_score,
        
        -- Density score (0-100)
        LEAST(100, groceries_within_1mile * 25) as density_score,
        
        -- Affordability score (0-100)
        CASE 
            WHEN avg_healthy_food_price IS NULL THEN 50
            WHEN median_household_income * 0.15 / 12 >= avg_healthy_food_price * 100 THEN 100
            WHEN median_household_income * 0.15 / 12 >= avg_healthy_food_price * 80 THEN 75
            WHEN median_household_income * 0.15 / 12 >= avg_healthy_food_price * 60 THEN 50
            ELSE 25
        END as affordability_score,
        
        -- Transportation score (0-100)
        ROUND(
            (vehicle_ownership_rate * 60) + 
            (LEAST(nearby_transit_stops / 3.0, 1.0) * 40)
        ) as transportation_score
        
    FROM comprehensive_analysis
)
SELECT 
    tract_id,
    area_name,
    total_population,
    ROUND(median_household_income, 0) as median_household_income,
    ROUND(poverty_rate, 1) as poverty_rate,
    ROUND(closest_grocery_miles, 2) as closest_grocery_miles,
    groceries_within_1mile,
    ROUND(vehicle_ownership_rate, 2) as vehicle_ownership_rate,
    nearby_transit_stops,
    distance_score,
    density_score,
    affordability_score,
    transportation_score,
    
    -- Overall Food Access Score (weighted average)
    ROUND(
        (distance_score * 0.3) + 
        (density_score * 0.25) + 
        (affordability_score * 0.25) + 
        (transportation_score * 0.2)
    ) as overall_food_access_score,
    
    -- Classification
    CASE 
        WHEN ROUND(
            (distance_score * 0.3) + 
            (density_score * 0.25) + 
            (affordability_score * 0.25) + 
            (transportation_score * 0.2)
        ) < 40 THEN 'Severe Food Desert'
        WHEN ROUND(
            (distance_score * 0.3) + 
            (density_score * 0.25) + 
            (affordability_score * 0.25) + 
            (transportation_score * 0.2)
        ) < 60 THEN 'Moderate Food Desert'
        WHEN ROUND(
            (distance_score * 0.3) + 
            (density_score * 0.25) + 
            (affordability_score * 0.25) + 
            (transportation_score * 0.2)
        ) < 80 THEN 'Limited Food Access'
        ELSE 'Adequate Food Access'
    END as food_desert_classification
    
FROM scored_analysis
ORDER BY overall_food_access_score ASC;

-- =====================================================

-- 5. Temporal Analysis - Track Changes Over Time
-- Compare food access metrics across different time periods
SELECT 
    'Temporal Trend Analysis' as analysis_type;

WITH monthly_snapshots AS (
    SELECT 
        DATE_FORMAT(fp.collection_date, '%Y-%m') as snapshot_month,
        ga.tract_id,
        ga.area_name,
        COUNT(DISTINCT fr.retailer_id) as active_retailers,
        AVG(fp.price_per_unit) as avg_food_price,
        AVG(CASE WHEN fp.nutritional_score >= 7 THEN fp.price_per_unit END) as avg_healthy_price,
        COUNT(CASE WHEN fr.accepts_snap = TRUE THEN 1 END) as snap_retailers
    FROM geographic_areas ga
    JOIN food_retailers fr ON calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
    JOIN food_prices fp ON fr.retailer_id = fp.retailer_id
    WHERE fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY DATE_FORMAT(fp.collection_date, '%Y-%m'), ga.tract_id, ga.area_name
),
trend_analysis AS (
    SELECT 
        tract_id,
        area_name,
        snapshot_month,
        active_retailers,
        avg_food_price,
        avg_healthy_price,
        snap_retailers,
        -- Calculate month-over-month changes using LAG simulation
        @prev_retailers := CASE 
            WHEN @prev_tract = tract_id THEN @prev_retailers 
            ELSE active_retailers 
        END as prev_retailers_temp,
        @prev_avg_price := CASE 
            WHEN @prev_tract = tract_id THEN @prev_avg_price 
            ELSE avg_food_price 
        END as prev_avg_price_temp,
        @prev_healthy_price := CASE 
            WHEN @prev_tract = tract_id THEN @prev_healthy_price 
            ELSE avg_healthy_price 
        END as prev_healthy_price_temp,
        @prev_tract := tract_id,
        @prev_retailers := active_retailers,
        @prev_avg_price := avg_food_price,
        @prev_healthy_price := avg_healthy_price
    FROM monthly_snapshots
    CROSS JOIN (SELECT @prev_tract := '', @prev_retailers := 0, @prev_avg_price := 0, @prev_healthy_price := 0) r
    ORDER BY tract_id, snapshot_month
)
SELECT 
    tract_id,
    area_name,
    snapshot_month,
    active_retailers,
    ROUND(avg_food_price, 2) as avg_food_price,
    ROUND(avg_healthy_price, 2) as avg_healthy_price,
    snap_retailers,
    -- Change indicators (simplified for MySQL)
    CASE 
        WHEN active_retailers > prev_retailers_temp AND 
             avg_healthy_price <= prev_healthy_price_temp THEN 'Improving'
        WHEN active_retailers < prev_retailers_temp OR 
             avg_healthy_price > prev_healthy_price_temp * 1.1 THEN 'Deteriorating'
        ELSE 'Stable'
    END as access_trend
FROM trend_analysis
WHERE snapshot_month >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 6 MONTH), '%Y-%m')
ORDER BY tract_id, snapshot_month DESC;

-- =====================================================

-- 6. Summary Dashboard Query
-- Executive summary for dashboard
SELECT 
    'Executive Dashboard Summary' as report_type;
show tables;

SELECT 
    COUNT(DISTINCT ga.tract_id) as total_areas_analyzed,
    SUM(ga.total_population) as total_population_covered,
    COUNT(DISTINCT fr.retailer_id) as total_food_retailers,
    ROUND(AVG(ga.median_household_income), 0) as avg_median_income,
    ROUND(AVG(ga.poverty_rate), 1) as avg_poverty_rate,
    COUNT(CASE WHEN fr.accepts_snap = TRUE THEN 1 END) as snap_accepting_retailers,
    ROUND(AVG(fp.price_per_unit), 2) as avg_food_price_current_month,
    COUNT(CASE WHEN calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) > 1.0 THEN 1 END) as areas_over_1mile_to_grocery
FROM geographic_areas ga
LEFT JOIN food_retailers fr ON calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 2.0
LEFT JOIN food_prices fp ON fr.retailer_id = fp.retailer_id 
    AND fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);

-- =====================================================

-- 7. Priority Intervention Areas
-- Top areas needing intervention (highest population, worst access)
SELECT 
    'Priority Intervention Areas' as report_type;

WITH intervention_priority AS (
    SELECT 
        ga.tract_id,
        ga.area_name,
        ga.total_population,
        ga.median_household_income,
        ga.poverty_rate,
        (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude))
         FROM food_retailers fr 
         WHERE fr.retailer_type IN ('supermarket', 'grocery')
           AND fr.fresh_produce_available = TRUE
        ) as closest_grocery_distance,
        (SELECT COUNT(*)
         FROM food_retailers fr 
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
           AND fr.retailer_type IN ('supermarket', 'grocery')
           AND fr.fresh_produce_available = TRUE
        ) as groceries_within_1mile
    FROM geographic_areas ga
)
SELECT 
    tract_id,
    area_name,
    total_population,
    ROUND(median_household_income, 0) as median_income,
    ROUND(poverty_rate, 1) as poverty_rate,
    ROUND(closest_grocery_distance, 2) as closest_grocery_miles,
    groceries_within_1mile,
    -- Priority score (higher = more urgent)
    ROUND(
        (total_population / 1000.0) * -- Population weight
        (CASE WHEN closest_grocery_distance > 1 THEN 2.0 ELSE 1.0 END) * -- Distance penalty
        (poverty_rate / 10.0) * -- Poverty weight
        (CASE WHEN median_household_income < 40000 THEN 1.5 ELSE 1.0 END) -- Income weight
    , 2) as intervention_priority_score
FROM intervention_priority
WHERE closest_grocery_distance > 0.5 OR groceries_within_1mile < 2
ORDER BY intervention_priority_score DESC
LIMIT 10;

-- =====================================================

-- 8. Data Quality Validation
-- Ensure data integrity and identify potential issues
SELECT 
    'Data Quality Report' as report_type;

SELECT 
    'Missing Coordinates' as issue_type,
    'food_retailers' as table_name,
    COUNT(*) as issue_count
FROM food_retailers 
WHERE latitude IS NULL OR longitude IS NULL

UNION ALL

SELECT 
    'Invalid Income Data' as issue_type,
    'geographic_areas' as table_name,
    COUNT(*) as issue_count
FROM geographic_areas 
WHERE median_household_income < 0 OR median_household_income > 500000

UNION ALL

SELECT 
    'Outdated Price Data' as issue_type,
    'food_prices' as table_name,
    COUNT(*) as issue_count
FROM food_prices 
WHERE collection_date < DATE_SUB(CURDATE(), INTERVAL 90 DAY)

UNION ALL

SELECT 
    'Unrealistic Prices' as issue_type,
    'food_prices' as table_name,
    COUNT(*) as issue_count
FROM food_prices 
WHERE price_per_unit <= 0 OR price_per_unit > 1000;

-- =====================================================

-- =====================================================
-- 9. Store Performance Analysis (CONTINUED)
-- Analyze individual store impact on food access
-- =====================================================

SELECT 
    'Store Performance Analysis' as report_type;

WITH store_impact AS (
    SELECT 
        fr.retailer_id,
        fr.name as store_name,
        fr.retailer_type,
        fr.latitude,
        fr.longitude,
        fr.fresh_produce_available,
        fr.accepts_snap,
        fr.store_size_sqft,
        
        -- Count population served within different radii
        (SELECT SUM(ga.total_population)
         FROM geographic_areas ga
         WHERE calculate_distance_miles(fr.latitude, fr.longitude, ga.latitude, ga.longitude) <= 0.5
        ) as population_within_halfmile,
        
        (SELECT SUM(ga.total_population)
         FROM geographic_areas ga
         WHERE calculate_distance_miles(fr.latitude, fr.longitude, ga.latitude, ga.longitude) <= 1.0
        ) as population_within_1mile,
        
        -- Average prices at this store
        (SELECT AVG(fp.price_per_unit)
         FROM food_prices fp
         WHERE fp.retailer_id = fr.retailer_id
           AND fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ) as avg_price_all_items,
        
        (SELECT AVG(fp.price_per_unit)
         FROM food_prices fp
         WHERE fp.retailer_id = fr.retailer_id
           AND fp.nutritional_score >= 7
           AND fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ) as avg_price_healthy_items,
        
        -- Count competing stores nearby
        (SELECT COUNT(*) - 1  -- Subtract self
         FROM food_retailers fr2
         WHERE fr2.retailer_type IN ('supermarket', 'grocery')
           AND fr2.fresh_produce_available = TRUE
           AND calculate_distance_miles(fr.latitude, fr.longitude, fr2.latitude, fr2.longitude) <= 1.0
        ) as competing_stores_nearby
        
    FROM food_retailers fr
    WHERE fr.retailer_type IN ('supermarket', 'grocery')
      AND fr.fresh_produce_available = TRUE
),
store_rankings AS (
    SELECT 
        *,
        -- Calculate store impact score
        ROUND(
            (COALESCE(population_within_1mile, 0) / 1000.0) * 0.4 +  -- Population served
            (CASE WHEN accepts_snap THEN 20 ELSE 0 END) * 0.2 +      -- SNAP accessibility
            (CASE WHEN avg_price_healthy_items < 5.0 THEN 20 ELSE 10 END) * 0.2 + -- Price competitiveness
            (COALESCE(store_size_sqft, 0) / 1000.0) * 0.1 +          -- Store size
            (CASE WHEN competing_stores_nearby = 0 THEN 20 ELSE 5 END) * 0.1  -- Uniqueness in area
        , 2) as store_impact_score
    FROM store_impact
)
SELECT 
    store_name,
    retailer_type,
    COALESCE(population_within_halfmile, 0) as pop_served_0_5mi,
    COALESCE(population_within_1mile, 0) as pop_served_1mi,
    accepts_snap,
    ROUND(COALESCE(avg_price_all_items, 0), 2) as avg_price_all,
    ROUND(COALESCE(avg_price_healthy_items, 0), 2) as avg_price_healthy,
    competing_stores_nearby,
    store_impact_score,
    CASE 
        WHEN store_impact_score >= 30 THEN 'High Impact'
        WHEN store_impact_score >= 20 THEN 'Medium Impact'
        WHEN store_impact_score >= 10 THEN 'Low Impact'
        ELSE 'Minimal Impact'
    END as impact_category
FROM store_rankings
ORDER BY store_impact_score DESC;

-- =====================================================

-- 10. Demographic Vulnerability Analysis
-- Identify most vulnerable populations for targeted interventions
-- =====================================================

SELECT 
    'Demographic Vulnerability Analysis' as report_type;

WITH vulnerability_metrics AS (
    SELECT 
        ga.tract_id,
        ga.area_name,
        ga.total_population,
        ga.median_household_income,
        ga.poverty_rate,
        ga.vehicle_ownership_rate,
        
        -- Calculate distance to nearest grocery
        (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude))
         FROM food_retailers fr 
         WHERE fr.retailer_type IN ('supermarket', 'grocery')
           AND fr.fresh_produce_available = TRUE
        ) as nearest_grocery_distance,
        
        -- Count SNAP-accepting stores nearby
        (SELECT COUNT(*)
         FROM food_retailers fr 
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
           AND fr.accepts_snap = TRUE
           AND fr.retailer_type IN ('supermarket', 'grocery')
        ) as snap_stores_within_1mile,
        
        -- Calculate vulnerability factors
        CASE WHEN ga.poverty_rate > 20 THEN 1 ELSE 0 END as high_poverty,
        CASE WHEN ga.median_household_income < 35000 THEN 1 ELSE 0 END as low_income,
        CASE WHEN ga.vehicle_ownership_rate < 0.6 THEN 1 ELSE 0 END as low_vehicle_access
        
    FROM geographic_areas ga
),
vulnerability_scores AS (
    SELECT 
        *,
        -- Vulnerability score (0-100, higher = more vulnerable)
        ROUND(
            (high_poverty * 25) +                                    -- Poverty factor
            (low_income * 20) +                                      -- Income factor
            (low_vehicle_access * 15) +                             -- Transportation factor
            (CASE WHEN nearest_grocery_distance > 1 THEN 25 ELSE 0 END) +  -- Distance factor
            (CASE WHEN snap_stores_within_1mile = 0 THEN 15 ELSE 0 END)    -- SNAP access factor
        ) as vulnerability_score
    FROM vulnerability_metrics
)
SELECT 
    tract_id,
    area_name,
    total_population,
    ROUND(median_household_income, 0) as median_income,
    ROUND(poverty_rate, 1) as poverty_rate,
    ROUND(vehicle_ownership_rate, 2) as vehicle_ownership_rate,
    ROUND(COALESCE(nearest_grocery_distance, 999), 2) as nearest_grocery_miles,
    snap_stores_within_1mile,
    vulnerability_score,
    CASE 
        WHEN vulnerability_score >= 75 THEN 'Extremely Vulnerable'
        WHEN vulnerability_score >= 50 THEN 'Highly Vulnerable'
        WHEN vulnerability_score >= 25 THEN 'Moderately Vulnerable'
        ELSE 'Low Vulnerability'
    END as vulnerability_category,
    -- Population at risk
    ROUND(total_population * (vulnerability_score / 100.0), 0) as estimated_at_risk_population
FROM vulnerability_scores
ORDER BY vulnerability_score DESC, total_population DESC;

-- =====================================================

-- 11. Seasonal Price Variation Analysis
-- Track how food prices change seasonally
-- =====================================================

SELECT 
    'Seasonal Price Analysis' as report_type;

WITH seasonal_prices AS (
    SELECT 
        MONTH(fp.collection_date) as price_month,
        MONTHNAME(fp.collection_date) as month_name,
        fp.product_category,
        fp.product_name,
        AVG(fp.price_per_unit) as avg_price,
        COUNT(*) as price_observations,
        MIN(fp.price_per_unit) as min_price,
        MAX(fp.price_per_unit) as max_price,
        STDDEV(fp.price_per_unit) as price_volatility
    FROM food_prices fp
    WHERE fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY MONTH(fp.collection_date), MONTHNAME(fp.collection_date), 
             fp.product_category, fp.product_name
    HAVING COUNT(*) >= 3  -- Only include items with sufficient data points
),
price_trends AS (
    SELECT 
        product_category,
        product_name,
        month_name,
        ROUND(avg_price, 2) as avg_monthly_price,
        price_observations,
        ROUND(price_volatility, 2) as price_volatility,
        -- Calculate percentage change from previous month (simplified)
        ROUND(((avg_price - LAG(avg_price) OVER (PARTITION BY product_category, product_name ORDER BY price_month)) 
               / LAG(avg_price) OVER (PARTITION BY product_category, product_name ORDER BY price_month)) * 100, 1) as month_over_month_change
    FROM seasonal_prices
)
SELECT 
    product_category,
    product_name,
    month_name,
    avg_monthly_price,
    price_observations,
    price_volatility,
    COALESCE(month_over_month_change, 0) as price_change_percent,
    CASE 
        WHEN price_volatility > 1.0 THEN 'High Volatility'
        WHEN price_volatility > 0.5 THEN 'Medium Volatility'
        ELSE 'Low Volatility'
    END as volatility_category
FROM price_trends
WHERE product_category = 'produce'  -- Focus on produce as it's most seasonal
ORDER BY product_category, product_name, month_name;

-- =====================================================

-- 12. Store Closure Impact Simulation
-- Simulate the impact of potential store closures
-- =====================================================

SELECT 
    'Store Closure Impact Simulation' as report_type;

WITH store_closure_simulation AS (
    SELECT 
        fr.retailer_id,
        fr.name as store_name,
        fr.retailer_type,
        
        -- Population that would lose their closest store
        (SELECT COUNT(*)
         FROM geographic_areas ga
         WHERE (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr2.latitude, fr2.longitude))
                FROM food_retailers fr2 
                WHERE fr2.retailer_id = fr.retailer_id
                  AND fr2.retailer_type IN ('supermarket', 'grocery')
                  AND fr2.fresh_produce_available = TRUE
               ) <= 
               (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr3.latitude, fr3.longitude))
                FROM food_retailers fr3 
                WHERE fr3.retailer_id != fr.retailer_id
                  AND fr3.retailer_type IN ('supermarket', 'grocery')
                  AND fr3.fresh_produce_available = TRUE
               )
        ) as areas_where_closest,
        
        -- Total population within 1 mile
        (SELECT SUM(ga.total_population)
         FROM geographic_areas ga
         WHERE calculate_distance_miles(fr.latitude, fr.longitude, ga.latitude, ga.longitude) <= 1.0
        ) as population_served,
        
        -- Average income of served population
        (SELECT AVG(ga.median_household_income)
         FROM geographic_areas ga
         WHERE calculate_distance_miles(fr.latitude, fr.longitude, ga.latitude, ga.longitude) <= 1.0
        ) as avg_served_income,
        
        -- Check if this is the only SNAP store in area
        CASE WHEN fr.accepts_snap = TRUE AND 
                  (SELECT COUNT(*)
                   FROM food_retailers fr2
                   WHERE fr2.retailer_id != fr.retailer_id
                     AND fr2.accepts_snap = TRUE
                     AND fr2.retailer_type IN ('supermarket', 'grocery')
                     AND calculate_distance_miles(fr.latitude, fr.longitude, fr2.latitude, fr2.longitude) <= 2.0
                  ) = 0
             THEN TRUE ELSE FALSE END as only_snap_store_in_area
        
    FROM food_retailers fr
    WHERE fr.retailer_type IN ('supermarket', 'grocery')
      AND fr.fresh_produce_available = TRUE
),
closure_risk_assessment AS (
    SELECT 
        *,
        -- Calculate closure impact score
        ROUND(
            (COALESCE(population_served, 0) / 1000.0) * 0.4 +        -- Population impact
            (areas_where_closest * 10) * 0.3 +                       -- Accessibility impact
            (CASE WHEN avg_served_income < 40000 THEN 20 ELSE 5 END) * 0.2 +  -- Income vulnerability
            (CASE WHEN only_snap_store_in_area THEN 30 ELSE 0 END) * 0.1      -- SNAP access criticality
        , 2) as closure_impact_score
    FROM store_closure_simulation
)
SELECT 
    store_name,
    retailer_type,
    areas_where_closest as areas_losing_closest_store,
    COALESCE(population_served, 0) as population_within_1mile,
    ROUND(COALESCE(avg_served_income, 0), 0) as avg_income_served,
    only_snap_store_in_area,
    closure_impact_score,
    CASE 
        WHEN closure_impact_score >= 50 THEN 'Critical - High Community Impact'
        WHEN closure_impact_score >= 30 THEN 'Significant Impact'
        WHEN closure_impact_score >= 15 THEN 'Moderate Impact'
        ELSE 'Low Impact'
    END as closure_risk_category
FROM closure_risk_assessment
ORDER BY closure_impact_score DESC;

-- =====================================================

-- 13. Healthy Food Availability Index
-- Comprehensive measure of healthy food access quality
-- =====================================================

SELECT 
    'Healthy Food Availability Index' as report_type;

WITH healthy_food_metrics AS (
    SELECT 
        ga.tract_id,
        ga.area_name,
        ga.total_population,
        ga.median_household_income,
        
        -- Count of healthy food options
        (SELECT COUNT(DISTINCT fr.retailer_id)
         FROM food_retailers fr
         JOIN food_prices fp ON fr.retailer_id = fp.retailer_id
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
           AND fp.nutritional_score >= 8
           AND fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ) as stores_with_high_nutrition_foods,
        
        -- Variety of healthy food categories available
        (SELECT COUNT(DISTINCT fp.product_category)
         FROM food_retailers fr
         JOIN food_prices fp ON fr.retailer_id = fp.retailer_id
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
           AND fp.nutritional_score >= 7
           AND fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ) as healthy_food_categories_available,
        
        -- Average price of healthy foods
        (SELECT AVG(fp.price_per_unit)
         FROM food_retailers fr
         JOIN food_prices fp ON fr.retailer_id = fp.retailer_id
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
           AND fp.nutritional_score >= 7
           AND fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ) as avg_healthy_food_price,
        
        -- Produce availability specifically
        (SELECT COUNT(DISTINCT fr.retailer_id)
         FROM food_retailers fr
         JOIN food_prices fp ON fr.retailer_id = fp.retailer_id
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
           AND fp.product_category = 'produce'
           AND fp.collection_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ) as stores_with_fresh_produce
        
    FROM geographic_areas ga
),
availability_index AS (
    SELECT 
        tract_id,
        area_name,
        total_population,
        median_household_income,
        stores_with_high_nutrition_foods,
        healthy_food_categories_available,
        ROUND(COALESCE(avg_healthy_food_price, 0), 2) as avg_healthy_food_price,
        stores_with_fresh_produce,
        
        -- Calculate Healthy Food Availability Index (0-100)
        ROUND(
            (LEAST(stores_with_high_nutrition_foods * 20, 100) * 0.3) +     -- Store availability
            (LEAST(healthy_food_categories_available * 20, 100) * 0.25) +   -- Food variety
            (LEAST(stores_with_fresh_produce * 25, 100) * 0.25) +           -- Produce access
            (CASE 
                WHEN avg_healthy_food_price = 0 THEN 0
                WHEN median_household_income * 0.15 / 12 >= avg_healthy_food_price * 100 THEN 100
                WHEN median_household_income * 0.15 / 12 >= avg_healthy_food_price * 80 THEN 75
                WHEN median_household_income * 0.15 / 12 >= avg_healthy_food_price * 60 THEN 50
                ELSE 25
            END * 0.2)                                                      -- Affordability
        ) as healthy_food_availability_index
        
    FROM healthy_food_metrics
)
SELECT 
    tract_id,
    area_name,
    total_population,
    ROUND(median_household_income, 0) as median_household_income,
    stores_with_high_nutrition_foods,
    healthy_food_categories_available,
    avg_healthy_food_price,
    stores_with_fresh_produce,
    ROUND(healthy_food_availability_index, 0) as availability_index,
    CASE 
        WHEN healthy_food_availability_index >= 80 THEN 'Excellent Healthy Food Access'
        WHEN healthy_food_availability_index >= 60 THEN 'Good Healthy Food Access'
        WHEN healthy_food_availability_index >= 40 THEN 'Fair Healthy Food Access'
        WHEN healthy_food_availability_index >= 20 THEN 'Poor Healthy Food Access'
        ELSE 'Very Poor Healthy Food Access'
    END as availability_category
FROM availability_index
ORDER BY healthy_food_availability_index DESC;

-- =====================================================

-- 14. Final Recommendations Query
-- Generate actionable recommendations based on analysis
-- =====================================================

-- =====================================================
-- MYSQL WORKBENCH - POLICY RECOMMENDATIONS QUERY
-- Urban Food Desert Analyzer
-- =====================================================

-- Select the database
USE urban_food_desert_analyzer;

-- Policy Recommendations Analysis
SELECT 
    'Policy Recommendations' as report_type;

-- Main query with CTE (Common Table Expression)
WITH recommendation_analysis AS (
    SELECT 
        ga.tract_id,
        ga.area_name,
        ga.total_population,
        ga.poverty_rate,
        ga.vehicle_ownership_rate,
        
        -- Key metrics for recommendations
        -- Find nearest grocery store distance
        (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude))
         FROM food_retailers fr 
         WHERE fr.retailer_type IN ('supermarket', 'grocery')
           AND fr.fresh_produce_available = TRUE
        ) as nearest_grocery_distance,
        
        -- Count SNAP-accepting stores within 1 mile
        (SELECT COUNT(*)
         FROM food_retailers fr 
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
           AND fr.accepts_snap = TRUE
        ) as snap_stores_nearby,
        
        -- Count transit stops within 0.5 mile
        (SELECT COUNT(*)
         FROM public_transit pt 
         WHERE calculate_distance_miles(ga.latitude, ga.longitude, pt.latitude, pt.longitude) <= 0.5
        ) as transit_stops_nearby
        
    FROM geographic_areas ga
)

-- Final SELECT with recommendations logic
SELECT 
    tract_id,
    area_name,
    total_population,
    ROUND(poverty_rate, 1) as poverty_rate,
    ROUND(COALESCE(nearest_grocery_distance, 999), 2) as nearest_grocery_miles,
    snap_stores_nearby,
    transit_stops_nearby,
    
    -- Generate specific recommendations using CASE statement
    CASE 
        WHEN nearest_grocery_distance > 2.0 AND total_population > 3000 
        THEN 'HIGH PRIORITY: Incentivize new grocery store development'
        
        WHEN nearest_grocery_distance > 1.0 AND vehicle_ownership_rate < 0.6 AND transit_stops_nearby < 2
        THEN 'MEDIUM PRIORITY: Improve public transportation to food retailers'
        
        WHEN snap_stores_nearby = 0 AND poverty_rate > 20
        THEN 'HIGH PRIORITY: Recruit SNAP-accepting retailers'
        
        WHEN nearest_grocery_distance > 1.0 AND total_population < 2000
        THEN 'Consider mobile food markets or delivery programs'
        
        WHEN transit_stops_nearby >= 2 AND nearest_grocery_distance > 0.5
        THEN 'Partner with transit authority for food access routes'
        
        ELSE 'Monitor for changes in food access'
    END as primary_recommendation,
    
    -- Calculate intervention urgency score
    ROUND(
        (total_population / 1000.0 * 0.3) +
        (CASE WHEN nearest_grocery_distance > 1 THEN 30 ELSE 0 END * 0.4) +
        (poverty_rate * 0.2) +
        (CASE WHEN snap_stores_nearby = 0 THEN 20 ELSE 0 END * 0.1)
    ) as intervention_urgency_score
    
FROM recommendation_analysis
WHERE nearest_grocery_distance > 0.5 OR snap_stores_nearby = 0
ORDER BY intervention_urgency_score DESC;

-- =====================================================
-- ADDITIONAL HELPER QUERIES FOR WORKBENCH
-- =====================================================

-- Query to check if the custom function exists
SELECT 
    ROUTINE_NAME, 
    ROUTINE_TYPE, 
    ROUTINE_DEFINITION 
FROM information_schema.ROUTINES 
WHERE ROUTINE_SCHEMA = 'urban_food_desert_analyzer' 
  AND ROUTINE_NAME = 'calculate_distance_miles';

-- Query to verify table data exists
SELECT 
    'Table Check' as check_type,
    'geographic_areas' as table_name,
    COUNT(*) as record_count
FROM geographic_areas
UNION ALL
SELECT 
    'Table Check' as check_type,
    'food_retailers' as table_name,
    COUNT(*) as record_count
FROM food_retailers
UNION ALL
SELECT 
    'Table Check' as check_type,
    'public_transit' as table_name,
    COUNT(*) as record_count
FROM public_transit;

-- Alternative query if CTE is not supported in older MySQL versions
-- =====================================================
-- ALTERNATIVE VERSION WITHOUT CTE (For MySQL < 8.0)
-- =====================================================

/*
SELECT 
    ga.tract_id,
    ga.area_name,
    ga.total_population,
    ROUND(ga.poverty_rate, 1) as poverty_rate,
    ROUND(COALESCE(
        (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude))
         FROM food_retailers fr 
         WHERE fr.retailer_type IN ('supermarket', 'grocery')
           AND fr.fresh_produce_available = TRUE), 999), 2) as nearest_grocery_miles,
    
    (SELECT COUNT(*)
     FROM food_retailers fr 
     WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
       AND fr.accepts_snap = TRUE
    ) as snap_stores_nearby,
    
    (SELECT COUNT(*)
     FROM public_transit pt 
     WHERE calculate_distance_miles(ga.latitude, ga.longitude, pt.latitude, pt.longitude) <= 0.5
    ) as transit_stops_nearby,
    
    CASE 
        WHEN (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude))
              FROM food_retailers fr 
              WHERE fr.retailer_type IN ('supermarket', 'grocery')
                AND fr.fresh_produce_available = TRUE) > 2.0 
             AND ga.total_population > 3000 
        THEN 'HIGH PRIORITY: Incentivize new grocery store development'
        
        WHEN (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude))
              FROM food_retailers fr 
              WHERE fr.retailer_type IN ('supermarket', 'grocery')
                AND fr.fresh_produce_available = TRUE) > 1.0 
             AND ga.vehicle_ownership_rate < 0.6 
             AND (SELECT COUNT(*) FROM public_transit pt 
                  WHERE calculate_distance_miles(ga.latitude, ga.longitude, pt.latitude, pt.longitude) <= 0.5) < 2
        THEN 'MEDIUM PRIORITY: Improve public transportation to food retailers'
        
        WHEN (SELECT COUNT(*) FROM food_retailers fr 
              WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
                AND fr.accepts_snap = TRUE) = 0 
             AND ga.poverty_rate > 20
        THEN 'HIGH PRIORITY: Recruit SNAP-accepting retailers'
        
        ELSE 'Monitor for changes in food access'
    END as primary_recommendation
    
FROM geographic_areas ga
WHERE (SELECT MIN(calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude))
       FROM food_retailers fr 
       WHERE fr.retailer_type IN ('supermarket', 'grocery')
         AND fr.fresh_produce_available = TRUE) > 0.5 
   OR (SELECT COUNT(*) FROM food_retailers fr 
       WHERE calculate_distance_miles(ga.latitude, ga.longitude, fr.latitude, fr.longitude) <= 1.0
         AND fr.accepts_snap = TRUE) = 0
ORDER BY ga.total_population DESC;
*/
-- =====================================================
-- END OF URBAN FOOD DESERT ANALYZER
-- =====================================================

-- Cleanup function (optional - use to reset database for fresh analysis)
-- DELIMITER //
-- CREATE PROCEDURE reset_database()
-- BEGIN
--     DROP TABLE IF EXISTS food_prices;
--     DROP TABLE IF EXISTS public_transit;
--     DROP TABLE IF EXISTS food_retailers;
--     DROP TABLE IF EXISTS geographic_areas;
--     DROP FUNCTION IF EXISTS calculate_distance_miles;
-- END//
-- DELIMITER ;

-- Performance optimization indexes (add these if dealing with large datasets)
-- CREATE INDEX idx_food_prices_date_score ON food_prices(collection_date, nutritional_score);
-- CREATE INDEX idx_retailers_type_produce ON food_retailers(retailer_type, fresh_produce_available);
-- CREATE INDEX idx_areas_income_poverty ON geographic_areas(median_household_income, poverty_rate);