-- Verify number of rows
SELECT
	COUNT(*)
FROM parking_violations;

-- Update empty strings to null values
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'violations_staging' AND data_type = 'text'
    LOOP
        RAISE NOTICE 'Updating column: %', r.column_name;
        EXECUTE format('UPDATE violations_staging SET %I = NULL WHERE TRIM(%I) = '''';', r.column_name, r.column_name);
    END LOOP;
END $$;



--*--*--*--*--*--*--
-------------- 1. Create a staging table to work on
-- Create staging table
CREATE TABLE violations_staging AS
SELECT * FROM parking_violations;

-- Check new table
SELECT * FROM violations_staging LIMIT 10;

SELECT COUNT(*) FROM violations_staging;
 


--*--*--*--*--*--*--
-------------- 2. Remove duplicated records
-- Identify duplicated rows
WITH duplicates AS (
SELECT
	summons_number,
	ROW_NUMBER() OVER(
    	PARTITION BY 
        	plate_id
        	,registration_state
        	,issue_date 
        	,violation_code
        	,violation_time
      		,house_number
      		,street_name
  	) - 1 AS duplicate, 
  	plate_id
    ,registration_state
    ,issue_date 
    ,violation_code
    ,violation_time
    ,house_number
    ,street_name
FROM 
	violations_staging
)

SELECT	*
FROM duplicates
WHERE
	duplicate > 0
ORDER  BY summons_number;


-- Delete duplicated rows
WITH duplicates AS (
SELECT
	summons_number,
	ROW_NUMBER() OVER(
    	PARTITION BY 
        	plate_id
        	,registration_state
        	,issue_date 
        	,violation_code
        	,violation_time
      		,house_number
      		,street_name
  	) - 1 AS duplicate, 
  	plate_id
    ,registration_state
    ,issue_date 
    ,violation_code
    ,violation_time
    ,house_number
    ,street_name
FROM 
	violations_staging
)

DELETE FROM violations_staging
WHERE summons_number IN (
	SELECT	summons_number
	FROM duplicates
	WHERE
		duplicate > 0
)


--*--*--*--*--*--*--
-------------- 3. Standardize the data
-- Enable the fuzzystrmatch module
SELECT * FROM pg_available_extensions WHERE name = 'fuzzystrmatch';  -- check if the extension is available
CREATE EXTENSION fuzzystrmatch; -- enable the extension 
SELECT * FROM pg_extension WHERE extname = 'fuzzystrmatch';  -- verify the extension is enabled

--Identify incorrect spellings based on soundex matches
SELECT DISTINCT vehicle_color AS original_color
	,
    CASE
        WHEN DIFFERENCE(vehicle_color, 'GRAY') = 4 THEN 'GRAY'
        WHEN DIFFERENCE(vehicle_color, 'BLUE') = 4 THEN 'BLUE'
        WHEN DIFFERENCE(vehicle_color, 'RED') = 4 THEN 'RED'
        WHEN DIFFERENCE(vehicle_color, 'YELLOW') = 4 THEN 'YELLOW'
        WHEN DIFFERENCE(vehicle_color, 'BLACK') = 4 THEN 'BLACK'
        WHEN DIFFERENCE(vehicle_color, 'GOLD') = 4 THEN 'GOLD'
        WHEN DIFFERENCE(vehicle_color, 'SILVER') = 4 THEN 'SILVER'
        WHEN DIFFERENCE(vehicle_color, 'PURPLE') = 4 THEN 'PURPLE'
        WHEN DIFFERENCE(vehicle_color, 'ORANGE') = 4 THEN 'ORANGE'
        WHEN DIFFERENCE(vehicle_color, 'GREEN') = 4 THEN 'GREEN'
        WHEN DIFFERENCE(vehicle_color, 'TAN') = 4 THEN 'TAN'
        WHEN DIFFERENCE(vehicle_color, 'BURGUNDY') = 4 THEN 'BURGUNDY'
        ELSE vehicle_color
    END AS transformed_color
FROM violations_staging
WHERE 
    DIFFERENCE(vehicle_color, 'GRAY') = 4 OR
    DIFFERENCE(vehicle_color, 'BLUE') = 4 OR
    DIFFERENCE(vehicle_color, 'RED') = 4 OR
    DIFFERENCE(vehicle_color, 'YELLOW') = 4 OR
    DIFFERENCE(vehicle_color, 'BLACK') = 4 OR
    DIFFERENCE(vehicle_color, 'GOLD') = 4 OR
    DIFFERENCE(vehicle_color, 'SILVER') = 4 OR
    DIFFERENCE(vehicle_color, 'PURPLE') = 4 OR
    DIFFERENCE(vehicle_color, 'ORANGE') = 4 OR
    DIFFERENCE(vehicle_color, 'GREEN') = 4 OR
    DIFFERENCE(vehicle_color, 'TAN') = 4 OR
    DIFFERENCE(vehicle_color, 'BURGUNDY') = 4
ORDER BY transformed_color;


-- Update colors based on their soundex code matches
UPDATE violations_staging pv 
SET vehicle_color = CASE
	WHEN DIFFERENCE(vehicle_color, 'GRAY') = 4 THEN 'GRAY'
	WHEN DIFFERENCE(vehicle_color, 'BLUE') = 4 THEN 'BLUE'
	WHEN DIFFERENCE(vehicle_color, 'RED') = 4 THEN 'RED'
	WHEN DIFFERENCE(vehicle_color, 'YELLOW') = 4 THEN 'YELLOW'
	WHEN DIFFERENCE(vehicle_color, 'BLACK') = 4 THEN 'BLACK'
	WHEN DIFFERENCE(vehicle_color, 'GOLD') = 4 THEN 'GOLD'
	WHEN DIFFERENCE(vehicle_color, 'SILVER') = 4 THEN 'SILVER'
	WHEN DIFFERENCE(vehicle_color, 'PURPLE') = 4 THEN 'PURPLE'
	WHEN DIFFERENCE(vehicle_color, 'ORANGE') = 4 THEN 'ORANGE'
	WHEN DIFFERENCE(vehicle_color, 'GREEN') = 4 THEN 'GREEN'
	WHEN DIFFERENCE(vehicle_color, 'TAN') = 4 THEN 'TAN'
	WHEN DIFFERENCE(vehicle_color, 'BURGUNDY') = 4 THEN 'BURGUNDY'
	ELSE vehicle_color
END;


-- Update correcting for common typos, variants and abbreviations
UPDATE violations_staging pv 
SET vehicle_color = CASE
	WHEN vehicle_color IN ('BRW', 'BRO', 'BRN', 'BR', 'BW') THEN 'BROWN'
	WHEN vehicle_color IN ('SL', 'SLV', 'SIL', 'SI', 'SILVE', 'SILV', 'SLV/G', 'SR', 'S') THEN 'SILVER'
	WHEN vehicle_color IN ('PURP') THEN 'PURPLE'
	WHEN vehicle_color IN ('YL', 'YW') THEN 'YELLOW'
	WHEN vehicle_color IN ('WHE', 'WT', 'WHIT', 'WHI', 'WHT', 'WHTE', 'WH', 'W') THEN 'WHITE'
	WHEN vehicle_color IN ('BLIU', 'BUE', 'BIU', 'B') THEN 'BLUE'
	WHEN vehicle_color IN ('YL') THEN 'YELLOW'
	WHEN vehicle_color IN ('BK', 'BC') THEN 'BLACK'
	WHEN vehicle_color IN ('BIEGE', 'BEGE') THEN 'BEIGE'
	WHEN vehicle_color IN ('GOD', 'GD', 'GL', 'RGOLD') THEN 'GOLD'
	WHEN vehicle_color IN ('COPPE', 'COPER') THEN 'COPPER'
	WHEN vehicle_color IN ('GY') THEN 'GRAY'
	WHEN vehicle_color IN ('GN') THEN 'GREEN'
	WHEN vehicle_color IN ('OR') THEN 'ORANGE'
	WHEN vehicle_color IN ('R') THEN 'RED'
	WHEN vehicle_color IN ('BURG', 'BERGE', 'BURGU') THEN 'BURGUNDY'
	ELSE vehicle_color
END;

-- Identify rermaining errors to update "manually"
SELECT DISTINCT vehicle_color
FROM violations_staging;

/*
 Some colors remain unchanged because they could not be identified (e.g., `NH`)  
 or were ambiguous (e.g., `G`, which could represent either Green or Gray). 
*/


--*--*--*--*--*--*--*--*--
-------------- 4. Handling missing and invalid values

-------------- Missing values in vechicle_body_type
-- Counting null values in `vechicle_body_type` to decide on the appropriate fill-in value
SELECT
    COUNT(*) AS cnt
FROM violations_staging
WHERE vehicle_body_type IS NULL;

-- Replace null values with a placeholder
UPDATE violations_staging
SET vehicle_body_type = COALESCE(vehicle_body_type, 'Unknown');


--- `registration_state` that are not two consecutive uppercase letters
SELECT 
	DISTINCT registration_state
FROM violations_staging
WHERE registration_state NOT SIMILAR TO '[A-Z]{2}';

-- update to null
UPDATE violations_staging
SET registration_state = NULL
WHERE registration_state NOT SIMILAR TO '[A-Z]{2}';


--- plate_types that do not match three consecutive uppercase letters
SELECT 
	DISTINCT plate_type
FROM violations_staging
WHERE plate_type NOT SIMILAR TO '[A-Z]{3}';

-- update to null
UPDATE violations_staging
SET plate_type = NULL
WHERE plate_type NOT SIMILAR TO '[A-Z]{3}';


--- Identify vehicle_make that that have forward slash, spaces, numbers, or are 3 or less char
SELECT 
	DISTINCT vehicle_make
FROM violations_staging
WHERE vehicle_make ~ '/|\s' OR vehicle_make ~ '[0-9]'
 OR LENGTH(vehicle_make) < 4;

UPDATE violations_staging
SET vehicle_make = TRIM(vehicle_make);

/*
 These remaining `vehicle_make` require further cleaning 
*/


--- Check for `vehicle_year` outside of the range 1970 and 2021
SELECT
  summons_number,
  plate_id,
  vehicle_year
FROM
  violations_staging
WHERE
  vehicle_year NOT BETWEEN 1970 AND 2021;

SELECT DISTINCT vehicle_year
FROM violations_staging 
WHERE
  vehicle_year NOT BETWEEN 1970 AND 2021;
ORDER BY 1;

-- Update extreme values to null
UPDATE violations_staging
SET vehicle_year = NULL
WHERE vehicle_year NOT BETWEEN 1970 AND 2021;

SELECT DISTINCT vehicle_year
FROM violations_staging
ORDER BY 1 DESC;



--*--*--*--*--*--*--*--*--
-------------- 5. Formatting dates and times

-------------- Converting dates to date type
-- Check if it can be converted (consistent format)
SELECT
  summons_number,
  DATE(issue_date) AS issue_date
  ,DATE(NULLIF(date_first_observed, '0')) AS date_first_observed -- null values in this column are 0 
FROM
  violations_staging;

-- Update type to date
ALTER TABLE violations_staging
ALTER COLUMN issue_date TYPE DATE USING issue_date::DATE;

ALTER TABLE violations_staging 
ALTER COLUMN date_first_observed TYPE DATE USING NULLIF(date_first_observed, '0')::DATE;


-- Update invalid time values
-- Identify values higher than 12 hours for from_ and to_ hours_in_effect
SELECT * 
FROM (
	SELECT 
		from_hours_in_effect
		,to_hours_in_effect
	FROM violations_staging 
	WHERE 
		to_hours_in_effect != 'ALL' AND 
		(to_hours_in_effect != '' OR from_hours_in_effect != '')
	)
WHERE LEFT(to_hours_in_effect, 2)::INT > 12

-- Manually change the 3 distinct values with incorrect format
UPDATE violations_staging
SET to_hours_in_effect = CASE
	WHEN to_hours_in_effect = '1600P' THEN '0400P'
	WHEN to_hours_in_effect = '1800P' THEN '0600P'
	WHEN to_hours_in_effect = '2000P' THEN '0800P'
	ELSE to_hours_in_effect
END;


-- Check that all the records with 'ALL' in from_ and to_ hours_in_effect correspond
SELECT
	from_hours_in_effect
	,to_hours_in_effect
FROM violations_staging
WHERE 
	(from_hours_in_effect = 'ALL' AND to_hours_in_effect != 'ALL')
	OR
	(to_hours_in_effect = 'ALL' AND from_hours_in_effect != 'ALL')
 
-- Change 'ALL' to 00:00 - 11:59 in from_ and to_ hours_in_effect
UPDATE violations_staging
SET from_hours_in_effect = CASE
	WHEN from_hours_in_effect = 'ALL' THEN '1200A'
	ELSE from_hours_in_effect
	END,
	to_hours_in_effect = CASE
	WHEN to_hours_in_effect = 'ALL' THEN '1159P'
	ELSE to_hours_in_effect
	END;

-- Check nulls in both from_ and to_ hours_in_effect
SELECT
	violation_time
	,from_hours_in_effect
	,to_hours_in_effect
FROM
	violations_staging
WHERE 
	from_hours_in_effect IS NULL AND to_hours_in_effect IS NULL;

-- Change nulls to 00:00 - 11:59
UPDATE violations_staging
SET from_hours_in_effect = CASE
	WHEN from_hours_in_effect IS NULL AND to_hours_in_effect IS NULL
	THEN '1200A'
	ELSE from_hours_in_effect
	END,
	to_hours_in_effect = CASE 
	WHEN from_hours_in_effect IS NULL AND to_hours_in_effect IS NULL
	THEN '1159P'
	ELSE to_hours_in_effect
	END 

	
--- Identify invalid time values (less than 5 char)
SELECT 	
	summons_number
	,violation_time
	,from_hours_in_effect
	,to_hours_in_effect
FROM violations_staging 
WHERE 
	from_hours_in_effect != 'ALL' AND
	(LENGTH(violation_time) != 5 OR
	LENGTH(from_hours_in_effect) != 5 OR
	LENGTH(to_hours_in_effect) != 5) 
	
	
-- Check only violation_time
SELECT 	
	summons_number
	,violation_time
	,from_hours_in_effect
	,to_hours_in_effect
FROM violations_staging 
WHERE 
	LENGTH(violation_time) != 5;
	
-- Manually change specific values that can be determined
UPDATE violations_staging
SET violation_time = CASE
	WHEN summons_number = '1413267488' THEN violation_time || 'P'
	WHEN summons_number = '1413267490' THEN violation_time || 'A'
	WHEN summons_number = '1446415636' THEN violation_time || 'A'
	ELSE violation_time
	END;
	
	
-- Check only from_hours_in_effect
SELECT 	
	summons_number
	,violation_time
	,from_hours_in_effect
	,to_hours_in_effect
FROM violations_staging 
WHERE 
	LENGTH(from_hours_in_effect) != 5;
	
-- Manually chang specific values that can be determined
UPDATE violations_staging
SET from_hours_in_effect = CASE
	WHEN summons_number = '1422683254' THEN from_hours_in_effect || 'A'
	WHEN summons_number = '1454070122' THEN from_hours_in_effect || 'A'
	WHEN summons_number = '1454093195' THEN from_hours_in_effect || 'P'
	WHEN summons_number = '1454169126' THEN from_hours_in_effect || 'A'
	WHEN summons_number = '1452145076' THEN from_hours_in_effect || 'A'
	ELSE from_hours_in_effect
	END;


-- Check only to_hours_in_effect
SELECT 	
	summons_number
	,violation_time
	,from_hours_in_effect
	,to_hours_in_effect
FROM violations_staging 
WHERE 
	LENGTH(to_hours_in_effect) != 5;

-- Manually changing specific values that can be determined
UPDATE violations_staging
SET to_hours_in_effect = CASE
	WHEN summons_number = '1422683254' THEN to_hours_in_effect || 'A'
	ELSE to_hours_in_effect
	END;


-- Identify when both from_ and to_ hours_into_effect are 0000
SELECT 	
	summons_number
	,from_hours_in_effect
	,to_hours_in_effect
FROM violations_staging
WHERE from_hours_in_effect = '0000' AND to_hours_in_effect = '0000';

-- Update this only value to match format
UPDATE violations_staging
SET from_hours_in_effect = CASE 
	WHEN summons_number = '1446646427' THEN '1200A'
	ELSE from_hours_in_effect
	END,
	to_hours_in_effect = CASE
	WHEN summons_number = '1446646427' THEN '1159P'
	ELSE to_hours_in_effect
	END;

-- Eliminate remaining invalid values
DELETE FROM violations_staging 
WHERE 
	from_hours_in_effect != 'ALL' AND
	(LENGTH(violation_time) != 5 OR
	LENGTH(from_hours_in_effect) != 5 OR
	LENGTH(to_hours_in_effect) != 5); 


-- Check invalid midnight format
SELECT
	DISTINCT 
	violation_time
	,from_hours_in_effect
	,to_hours_in_effect
FROM violations_staging
WHERE SUBSTR(violation_time, 1, 2) = '24' 
	OR SUBSTR(violation_time, 1, 2) = '00';

-- Update midnight format to 12
UPDATE violations_staging
SET violation_time = CASE
	WHEN SUBSTR(violation_time, 1, 2) = '24' THEN '12' || SUBSTR(violation_time, 3, 3)
	WHEN SUBSTR(violation_time, 1, 2) = '00' THEN '12' || SUBSTR(violation_time, 3, 3)
	ELSE violation_time
END


-- identify values higher than 12
SELECT violation_time
FROM violations_staging
WHERE SUBSTR(violation_time, 1, 2)::int > 12; 

-- Update the only 2 distinct values with incorrect format
UPDATE violations_staging
SET violation_time = CASE
	WHEN SUBSTR(violation_time, 1, 2)::int = 19 THEN '07' || SUBSTR(violation_time, 3, 3)
	WHEN SUBSTR(violation_time, 1, 2)::int = 16 THEN '04' || SUBSTR(violation_time, 3, 3)
	ELSE violation_time
END;


-- Change the time formats hhmma format to hh:mm:ss
SELECT
  TO_TIMESTAMP(from_hours_in_effect || 'M', 'HH12MIAM')::TIME AS conv_from_hours
  ,from_hours_in_effect
  ,TO_TIMESTAMP(to_hours_in_effect || 'M', 'HH12MIAM')::TIME AS conv_to_hours
  ,to_hours_in_effect
  ,TO_TIMESTAMP(violation_time || 'M', 'HH12MIAM')::TIME AS conv_violation_time
  ,violation_time
FROM
  violations_staging;

-- Update times type
UPDATE violations_staging
SET from_hours_in_effect = TO_TIMESTAMP(from_hours_in_effect || 'M', 'HH12MIAM')::TIME,
	to_hours_in_effect = TO_TIMESTAMP(to_hours_in_effect || 'M', 'HH12MIAM')::TIME,
	violation_time = TO_TIMESTAMP(violation_time || 'M', 'HH12MIAM')::TIME;


SELECT from_hours_in_effect, to_hours_in_effect, violation_time 
FROM violations_staging;



-------------- Identify invalid parking violations based on the range of hours in effect
-- Invalid records without overnight restrictions
SELECT 
  summons_number, 
  violation_time, 
  from_hours_in_effect, 
  to_hours_in_effect 
FROM 
  violations_staging
WHERE 
  from_hours_in_effect < to_hours_in_effect AND 
  violation_time NOT BETWEEN from_hours_in_effect AND to_hours_in_effect;


-- Invalid records including overnight parking restrictions
SELECT
  summons_number,
  violation_time,
  from_hours_in_effect,
  to_hours_in_effect
FROM
  violations_staging
WHERE
  from_hours_in_effect > to_hours_in_effect AND
  violation_time < from_hours_in_effect AND
  violation_time > to_hours_in_effect;





