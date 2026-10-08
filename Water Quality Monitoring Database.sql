/*
Project: Water Quality Monitoring Database & SQL Analysis
Technology: MySQL / MySQL Workbench

Project Context:
This project used Chesapeake Bay water-quality monitoring data provided
as a flat CSV file. Using the supplied relational schema, I created and
populated normalized tables in MySQL, created the table relationships,
executed analytical SQL queries, and created a database backup.

Source:
Chesapeake Bay Program Water Quality Data
https://datahub.chesapeakebay.net/WaterQuality
*/

USE courseproject;


-- ============================================================
-- 1. CREATE NORMALIZED TABLES
-- ============================================================

CREATE TABLE Station (
    StationId INT PRIMARY KEY,
    FIPS VARCHAR(10),
    Latitude DECIMAL(10,6),
    Longitude DECIMAL(10,6)
);

CREATE TABLE Event (
    EventId INT AUTO_INCREMENT PRIMARY KEY,
    StationId INT,
    Cruise VARCHAR(50),
    Program VARCHAR(100),
    Project VARCHAR(100),
    Agency VARCHAR(100),
    Source VARCHAR(100),
    TierLevel VARCHAR(50),
    FOREIGN KEY (StationId) REFERENCES Station(StationId)
);

CREATE TABLE Sample (
    SampleId INT AUTO_INCREMENT PRIMARY KEY,
    StationId INT,
    SampleDate DATE,
    SampleTime TIME NULL,
    TotalDepth DECIMAL(10,2) NULL,
    UpperPycnocline DECIMAL(10,2) NULL,
    LowerPycnocline DECIMAL(10,2) NULL,
    Depth DECIMAL(10,2) NULL,
    Layer VARCHAR(50) NULL,
    SampleType VARCHAR(50) NULL,
    SampleReplicateType VARCHAR(10),
    FOREIGN KEY (StationId) REFERENCES Station(StationId)
);

CREATE TABLE Parameter (
    ParameterId INT AUTO_INCREMENT PRIMARY KEY,
    Parameter VARCHAR(100)
);

CREATE TABLE Method (
    MethodId INT AUTO_INCREMENT PRIMARY KEY,
    Method VARCHAR(100)
);

CREATE TABLE Lab (
    LabId INT AUTO_INCREMENT PRIMARY KEY,
    Lab VARCHAR(100)
);

CREATE TABLE Measure (
    MeasureId INT AUTO_INCREMENT PRIMARY KEY,
    SampleId INT,
    ParameterId INT,
    MethodId INT,
    LabId INT NULL,
    Qualifier VARCHAR(50) NULL,
    MeasureValue DECIMAL(12,4) NULL,
    Unit VARCHAR(50) NULL,
    Problem VARCHAR(255) NULL,
    PrecisionPC DECIMAL(10,4) NULL,
    BiasPC DECIMAL(10,4) NULL,
    Details TEXT NULL,
    FOREIGN KEY (SampleId) REFERENCES Sample(SampleId),
    FOREIGN KEY (ParameterId) REFERENCES Parameter(ParameterId),
    FOREIGN KEY (MethodId) REFERENCES Method(MethodId),
    FOREIGN KEY (LabId) REFERENCES Lab(LabId)
);


-- ============================================================
-- 2. POPULATE TABLES FROM RAW DATA
-- ============================================================

-- Populate Station
INSERT INTO Station (StationId, FIPS, Latitude, Longitude)
SELECT DISTINCT
    Station,
    FIPS,
    Latitude,
    Longitude
FROM raw_water_quality;


-- Populate Event
INSERT INTO Event (
    StationId,
    Cruise,
    Program,
    Project,
    Agency,
    Source,
    TierLevel
)
SELECT DISTINCT
    Station,
    Cruise,
    Program,
    Project,
    Agency,
    Source,
    TierLevel
FROM raw_water_quality;


-- Populate Sample
INSERT INTO Sample (
    StationId,
    SampleDate,
    SampleTime,
    TotalDepth,
    UpperPycnocline,
    LowerPycnocline,
    Depth,
    Layer,
    SampleType,
    SampleReplicateType
)
SELECT DISTINCT
    Station,
    STR_TO_DATE(SampleDate, '%m/%d/%Y'),
    SampleTime,
    NULLIF(TotalDepth, ''),
    NULLIF(UpperPycnocline, ''),
    NULLIF(LowerPycnocline, ''),
    NULLIF(Depth, ''),
    Layer,
    SampleType,
    SampleReplicateType
FROM raw_water_quality;


-- Populate Parameter
INSERT INTO Parameter (Parameter)
SELECT DISTINCT
    Parameter
FROM raw_water_quality;


-- Populate Method
INSERT INTO Method (Method)
SELECT DISTINCT
    Method
FROM raw_water_quality;


-- Populate Lab
INSERT INTO Lab (Lab)
SELECT DISTINCT
    Lab
FROM raw_water_quality
WHERE Lab IS NOT NULL;


-- Populate Measure
INSERT INTO Measure (
    SampleId,
    ParameterId,
    MethodId,
    LabId,
    Qualifier,
    MeasureValue,
    Unit,
    Problem,
    PrecisionPC,
    BiasPC,
    Details
)
SELECT
    s.SampleId,
    p.ParameterId,
    m.MethodId,
    l.LabId,
    r.Qualifier,
    NULLIF(r.MeasureValue, ''),
    r.Unit,
    r.Problem,
    NULLIF(r.PrecisionPC, ''),
    NULLIF(r.BiasPC, ''),
    r.Details
FROM raw_water_quality r
JOIN Sample s
    ON s.StationId = r.Station
    AND s.SampleDate = STR_TO_DATE(r.SampleDate, '%m/%d/%Y')
    AND s.SampleReplicateType = r.SampleReplicateType
JOIN Parameter p
    ON p.Parameter = r.Parameter
JOIN Method m
    ON m.Method = r.Method
LEFT JOIN Lab l
    ON l.Lab = r.Lab;


-- ============================================================
-- 3. ANALYTICAL QUERIES
-- ============================================================

-- Q1:
-- What is the average CHLA concentration for each month,
-- and how does it compare with the overall CHLA average?

SELECT
    MONTH(s.SampleDate) AS Month,
    AVG(m.MeasureValue) AS Avg_CHLA,
    (
        SELECT AVG(m2.MeasureValue)
        FROM Measure m2
        JOIN Parameter p2
            ON m2.ParameterId = p2.ParameterId
        WHERE p2.Parameter = 'CHLA'
    ) AS Overall_Avg_CHLA
FROM Measure m
JOIN Sample s
    ON m.SampleId = s.SampleId
JOIN Parameter p
    ON m.ParameterId = p.ParameterId
WHERE p.Parameter = 'CHLA'
GROUP BY MONTH(s.SampleDate)
ORDER BY Month;


-- Q2:
-- What are the maximum and minimum CHLA concentrations at each
-- station, and when were those measurements taken?

SELECT
    st.StationId,
    'MAX' AS Type,
    m.MeasureValue,
    s.SampleDate,
    s.SampleTime
FROM Measure m
JOIN Sample s
    ON m.SampleId = s.SampleId
JOIN Parameter p
    ON m.ParameterId = p.ParameterId
JOIN Station st
    ON s.StationId = st.StationId
WHERE p.Parameter = 'CHLA'
  AND m.MeasureValue = (
      SELECT MAX(m2.MeasureValue)
      FROM Measure m2
      JOIN Sample s2
          ON m2.SampleId = s2.SampleId
      JOIN Parameter p2
          ON m2.ParameterId = p2.ParameterId
      WHERE p2.Parameter = 'CHLA'
        AND s2.StationId = st.StationId
  )

UNION

SELECT
    st.StationId,
    'MIN' AS Type,
    m.MeasureValue,
    s.SampleDate,
    s.SampleTime
FROM Measure m
JOIN Sample s
    ON m.SampleId = s.SampleId
JOIN Parameter p
    ON m.ParameterId = p.ParameterId
JOIN Station st
    ON s.StationId = st.StationId
WHERE p.Parameter = 'CHLA'
  AND m.MeasureValue = (
      SELECT MIN(m2.MeasureValue)
      FROM Measure m2
      JOIN Sample s2
          ON m2.SampleId = s2.SampleId
      JOIN Parameter p2
          ON m2.ParameterId = p2.ParameterId
      WHERE p2.Parameter = 'CHLA'
        AND s2.StationId = st.StationId
  )
ORDER BY StationId, Type;


-- Q3:
-- How many samples were taken for each SampleReplicateType
-- across all stations?

SELECT
    SampleReplicateType,
    COUNT(*) AS Sample_Count
FROM Sample
GROUP BY SampleReplicateType
ORDER BY Sample_Count DESC;


-- Q4:
-- Which station-month combinations had CHLA values
-- that did not exceed 18.0 ug/L?

SELECT
    st.StationId,
    MONTH(s.SampleDate) AS Month
FROM Measure m
JOIN Sample s
    ON m.SampleId = s.SampleId
JOIN Parameter p
    ON m.ParameterId = p.ParameterId
JOIN Station st
    ON s.StationId = st.StationId
WHERE p.Parameter = 'CHLA'
GROUP BY st.StationId, MONTH(s.SampleDate)
HAVING MAX(m.MeasureValue) <= 18.0
ORDER BY st.StationId, Month;


-- ============================================================
-- 4. DATA VALIDATION
-- ============================================================

-- Preview Sample table
SELECT *
FROM Sample
LIMIT 5;


-- Preview Measure table
SELECT *
FROM Measure
LIMIT 5;