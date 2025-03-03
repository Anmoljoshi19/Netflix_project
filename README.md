[Netflix SQL Project](https://github.com/Anmoljoshi19/Netflix_project/blob/main/netflix_titles.csv)

**Overview**

This project analyzes Netflix's content to uncover trends in movies, TV shows, genres, and ratings.
The dataset was cleaned and structured in MySQL for smooth analysis. Key focus areas include content
distribution, top-rated shows, country-wise contributions, and recent additions.

--------------------------------------------------------------------------------------------------------------------------

**Tools Used**

MS Excel & MySQL – Data Cleaning, Transformation & Analysis

--------------------------------------------------------------------------------------------------------------------------

**Dataset**

- show_id: Unique identifier
- type: 'Movie' or 'TV Show'
- title: Name of the content
- director: Name of the director(s)
- cast: List of actors
- country: Country of production
- date_added: Date added to Netflix
- release_year: Year of release
- rating: Content rating (e.g., PG-13, TV-MA)
- duration: Runtime (in minutes for movies, seasons for TV shows)
- listed_in: Genre categories

Before importing, certain characters like double quotes (") were replaced with asterisks (*) to prevent formatting issues.
The description column was removed due to excessive special characters. 
Blank spaces in the dataset were replaced with NULL to standardize missing values and improve query accuracy.

--------------------------------------------------------------------------------------------------------------------------

**Data Cleaning & Standardization**
```sql

-- Creating the Netflix Titles Table

CREATE TABLE netflix_titles (
    show_id VARCHAR(15),
    type VARCHAR(15),
    title VARCHAR(300),
    director VARCHAR(600),
    cast VARCHAR(1000),
    country VARCHAR(600),
    date_added VARCHAR(50),
    release_year VARCHAR(50),
    rating VARCHAR(50),
    duration VARCHAR(50),
    listed_in VARCHAR(600)
);

-- Loading Data into the Table

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/netflix_titles.csv'
INTO TABLE netflix_titles
FIELDS TERMINATED BY ','  
OPTIONALLY ENCLOSED BY '"'  
LINES TERMINATED BY '\n'  
IGNORE 1 ROWS;

-- Cleaning and Standardizing Data

UPDATE netflix_titles 
SET 
    country = REPLACE(country, '*', ','),
    listed_in = REPLACE(listed_in, '*', ','),
    cast = REPLACE(cast, '*', ','),
    director = REPLACE(director, '*', ',');

-- Handling Incorrect Rating Values

UPDATE netflix_titles 
SET duration = rating
WHERE rating LIKE ('%min%');

UPDATE netflix_titles 
SET rating = NULL
WHERE rating LIKE ('%min%');

-- Removing Duplicate Titles

WITH cte AS (
    SELECT show_id, ROW_NUMBER() OVER (PARTITION BY title ORDER BY show_id) AS rn
    FROM netflix_titles
)
DELETE FROM netflix_titles WHERE show_id IN (SELECT show_id FROM cte WHERE rn = 2);

-- Standardizing Date Format

UPDATE netflix_titles 
SET date_added = STR_TO_DATE(CONCAT_WS('-',
                    SUBSTRING_INDEX(SUBSTRING_INDEX(date_added, ' ', -2), '*', 1),
                    LEFT(TRIM(date_added), 3),
                    RIGHT(date_added, 4)),
            '%d-%b-%Y')
WHERE date_added IS NOT NULL AND date_added <> '';

ALTER TABLE netflix_titles
MODIFY COLUMN date_added DATE;

```
--------------------------------------------------------------------------------------------------------------------------

**Business Problems and Queries**
```sql

-- 1. Count the number of Movies vs TV Shows

SELECT type, COUNT(type) AS Count
FROM netflix_titles
GROUP BY type 
UNION ALL 
SELECT 'Total', COUNT(*) FROM netflix_titles;

--------------------------------------------------------------------------------------------------------------------------

-- 2. Find the most common rating for movies and TV shows

SELECT type, rating, rating_Count 
FROM (
    SELECT type, rating, COUNT(*) AS rating_Count,
           RANK() OVER (PARTITION BY type ORDER BY COUNT(*) DESC) AS rn
    FROM netflix_titles
    GROUP BY type, rating
) AS data_rank
WHERE rn = 1;

--------------------------------------------------------------------------------------------------------------------------

-- 3. List all movies released in a specific year (e.g., 2020)

SELECT title
FROM netflix_titles
WHERE type = 'Movie' AND release_year = 2020;

--------------------------------------------------------------------------------------------------------------------------

-- 4. Find the top 5 countries with the most content on Netflix

SELECT TRIM(value) AS country, COUNT(*) AS count 
FROM netflix_titles,
JSON_TABLE (CONCAT('["', REPLACE(country, ',', '","'), '"]'),
'$[*]' COLUMNS(value VARCHAR(200) PATH '$')) AS temp
GROUP BY country
ORDER BY count DESC
LIMIT 5;

--------------------------------------------------------------------------------------------------------------------------

-- 5. Identify the longest movie

SELECT title, 
       MAX(CAST(TRIM(REPLACE(duration, 'min', '')) AS UNSIGNED)) AS max_duration
FROM netflix_titles
WHERE type = 'Movie'
GROUP BY title
ORDER BY max_duration DESC
LIMIT 1;

--------------------------------------------------------------------------------------------------------------------------

-- 6. Find content added in the last 5 years

SELECT title, date_added, TIMESTAMPDIFF(YEAR, date_added, CURDATE()) AS year_diff
FROM netflix_titles
WHERE TIMESTAMPDIFF(YEAR, date_added, CURDATE()) <= 5;

--------------------------------------------------------------------------------------------------------------------------

-- 7. Find all movies/TV shows by director 'Rajiv Chilaka'

SELECT title
FROM netflix_titles
WHERE director LIKE '%Rajiv Chilaka%';

--------------------------------------------------------------------------------------------------------------------------

-- 8. List all TV shows with more than 5 seasons

SELECT title, REGEXP_SUBSTR(duration, '[0-9]+') AS season_count
FROM netflix_titles
WHERE type = 'TV Show' AND REGEXP_SUBSTR(duration, '[0-9]+') >= 5;

--------------------------------------------------------------------------------------------------------------------------

-- 9. Count the number of content items in each genre

SELECT TRIM(value) AS genre, COUNT(*) AS count
FROM netflix_titles,
JSON_TABLE(CONCAT('["', REPLACE(REPLACE(listed_in, ',', '","'), '\r', ''), '"]'),
'$[*]' COLUMNS(value VARCHAR(300) PATH '$')) AS temp
GROUP BY genre
ORDER BY count DESC;

--------------------------------------------------------------------------------------------------------------------------

-- 10. Find the top 5 years with the highest average content release in India

SELECT YEAR(date_added) AS year, COUNT(*) AS content_count,
       ROUND((COUNT(*) / (SELECT COUNT(*) FROM netflix_titles WHERE country = 'India')) * 100, 2) AS average
FROM netflix_titles
GROUP BY year, country
HAVING country = 'India'
ORDER BY content_count DESC
LIMIT 5;

--------------------------------------------------------------------------------------------------------------------------

-- 11. List all movies that are documentaries

SELECT title
FROM netflix_titles
WHERE listed_in LIKE '%documentaries%' AND type = 'Movie';

--------------------------------------------------------------------------------------------------------------------------

-- 12. Find all content without a director

SELECT title
FROM netflix_titles
WHERE director IS NULL;

--------------------------------------------------------------------------------------------------------------------------

-- 13. Find how many movies actor 'Salman Khan' appeared in last 10 years

SELECT title, release_year, (YEAR(CURDATE()) - release_year) AS years_since_release
FROM netflix_titles
WHERE cast LIKE '%Salman Khan%' AND (YEAR(CURDATE()) - release_year) <= 10;

--------------------------------------------------------------------------------------------------------------------------

-- 14. Find the top 10 actors with the highest appearances in Indian movies

SELECT Actor_names, Appearance 
FROM (
    SELECT TRIM(value) AS Actor_names, COUNT(*) AS Appearance, country, type
    FROM netflix_titles,
    JSON_TABLE(CONCAT('["', REPLACE(cast, ',', '","'), '"]'),
    '$[*]' COLUMNS(value VARCHAR(200) PATH '$')) AS temp
    GROUP BY Actor_names, country, type
    HAVING country LIKE '%India%' AND type = 'Movie'
    ORDER BY Appearance DESC
    LIMIT 10
) AS Actor_data;

```

[SQL-Code-Netflix-Finding-Insights-Project](https://github.com/Anmoljoshi19/Netflix_project/blob/main/Netflix_titles.sql)

--------------------------------------------------------------------------------------------------------------------------

**Conclusion**
Key insights from the analysis:

1. **Movies dominate Netflix’s library** over TV shows.
2. **Most common ratings** for movies and shows were identified.
3. **2020 saw a high number of movie releases**.
4. **Top 5 countries** with the most content were identified.
5. **Longest movie on Netflix** was determined.
6. **Content added in the last 5 years** was analyzed.
7. **Actor & director trends** were explored.
8. **Genre distribution** of content was mapped.
9. **Indian content growth** was studied.
10. **Actors with the most appearances** in Indian movies were listed.

These findings offer insights into Netflix’s content strategy and audience preferences.













