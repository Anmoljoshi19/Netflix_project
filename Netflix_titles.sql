-- Before importing data i have replace '"' into "*" and delete discription column from csv file because it contain many charaters which will create problem in importing data and replaced blank spaces with NULL.

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


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/netflix_titles.csv'
INTO TABLE netflix_titles
FIELDS TERMINATED BY ','  
optionally enclosed BY '"'  
LINES TERMINATED BY '\n'  
IGNORE 1 ROWS;


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Cleaning and Standardising

UPDATE netflix_titles 
SET 
    country = REPLACE(country, '*', ','),
    listed_in = REPLACE(listed_in, '*', ','),
    cast = REPLACE(cast, '*', ','),
    director = REPLACE(director, '*', ',');

----------------------------------------------------
UPDATE netflix_titles 
SET 
    duration = rating
WHERE
    rating LIKE ('%min%');

UPDATE netflix_titles 
SET 
    rating = NULL
WHERE
    rating LIKE ('%min%');

------------------------------------------------

select show_id,title, row_number() over (partition by title order by title) as rn
from netflix_titles
order by 3 desc;

WITH cte AS (
    SELECT show_id, ROW_NUMBER() OVER (PARTITION BY title ORDER BY show_id) AS rn
    FROM netflix_titles
)
DELETE FROM netflix_titles WHERE show_id IN (SELECT show_id FROM cte WHERE rn = 2);

--------------------------------------------------

UPDATE netflix_titles 
SET 
    DATE_added = STR_TO_DATE(CONCAT_WS('-',
                    SUBSTRING_INDEX(SUBSTRING_INDEX(DATE_added, ' ', - 2),
                            '*',
                            1),
                    LEFT(TRIM(DATE_added), 3),
                    RIGHT(DATE_added, 4)),
            '%d-%b-%Y')
WHERE
    DATE_added IS NOT NULL
        AND DATE_added <> '';

alter table netflix_titles
modify column date_added date;

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Business Problems

-- 1. Count the number of Movies vs TV Shows

SELECT DISTINCT
    (type), COUNT(type) AS Count
FROM
    netflix_titles
GROUP BY type 
UNION ALL SELECT 
    'Total', COUNT(*)
FROM
    netflix_titles;

-- 2. Find the most common rating for movies and TV shows

SELECT type, rating, rating_Count 
from (select  type ,rating, count(*) as rating_Count,  rank () over (partition by type order by count(*) desc) as rn  from netflix_titles
group by type , rating 
order by type, count(*) desc) as data_rank
where rn = 1;

-- 3. List all movies released in a specific year (e.g., 2020)

SELECT 
    title
FROM
    netflix_titles
WHERE
    type = 'Movie' AND release_year = 2020;
    
-- 4. Find the top 5 countries with the most content on Netflix

select trim(value) as item, count(*) as count from netflix_titles,
JSON_TABLE (concat('["', replace(country, ',', '","'),'"]'),
'$[*]' columns(value varchar(200) path '$')) as temp
group by item
order by count desc
limit 5;

-- 5. Identify the longest movie

SELECT 
    title,
    MAX(CAST(TRIM(REPLACE(duration, 'min', '')) AS UNSIGNED)) AS max_duration
FROM
    netflix_titles
WHERE
    type = 'Movie'
GROUP BY title
ORDER BY max_duration DESC
LIMIT 1;

-- 6. Find content added in the last 5 years

SELECT 
    title,
    date_added,
    TIMESTAMPDIFF(YEAR,
        date_added,
        CURDATE()) AS year_diff
FROM
    netflix_titles
WHERE
    TIMESTAMPDIFF(YEAR,
        date_added,
        CURDATE()) <= 5;

-- 7. Find all the movies/TV shows by director 'Rajiv Chilaka'!

SELECT 
    title
FROM
    netflix_titles
WHERE
    director LIKE '%Rajiv Chilaka%';

-- 8. List all TV shows with more than 5 seasons

SELECT 
    title, REGEXP_SUBSTR(duration, '[0-9]+') AS season_count
FROM
    netflix_titles
WHERE
    type = 'TV Show'
        AND REGEXP_SUBSTR(duration, '[0-9]+') >= 5;

-- 9. Count the number of content items in each genre

select trim(value) as item, count(*) as count
from netflix_titles,
JSON_TABLE(concat('["',replace(replace(listed_in, ',', '","'),'\r', ''),'"]'),
'$[*]' columns(value varchar(300) path '$')) as temp
GROUP BY item
order by count desc;

-- 10.Find each year and the average numbers of content release in India on netflix, return top 5 year with highest avg content release.

SELECT 
    YEAR(date_added) AS year,
    COUNT(*) AS content_count,
    ROUND((COUNT(*) / (SELECT 
                    COUNT(*)
                FROM
                    netflix_titles
                WHERE
                    country = 'India')) * 100,
            2) AS average
FROM
    netflix_titles
GROUP BY year , country
HAVING (country = 'India')
ORDER BY content_count DESC
LIMIT 5;

-- 11. List all movies that are documentaries

SELECT 
    title
FROM
    netflix_titles
WHERE
    listed_in LIKE '%documentaries%'
        AND type = 'Movie';

-- 12. Find all content without a director

SELECT 
    title
FROM
    netflix_titles
WHERE
    director IS NULL;

-- 13. Find how many movies actor 'Salman Khan' appeared in last 10 years!

SELECT 
    title, release_year, (YEAR(CURDATE()) - release_year)
FROM
    netflix_titles
WHERE
    cast LIKE '%Salman Khan%'
        AND (YEAR(CURDATE()) - release_year) <= 10;

-- 14. Find the top 10 actors who have appeared in the highest number of movies produced in India.

select Actor_names, Appearance from ( select trim(value) as Actor_names , count(*) as Appearance, country, type
from netflix_titles,
JSON_TABLE(concat('["', replace(cast,',','","'),'"]'),
'$[*]' columns(value varchar(200) path '$'
)) as temp
group by Actor_names , country, type having(country like '%india%') and (type = 'Movie') 
ORDER BY Appearance desc
limit 10) as Actor_data
