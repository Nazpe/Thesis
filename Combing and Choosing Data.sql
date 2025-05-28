USE DW_PNEUMONIA;

----------Eliminate before running the rest---------

DROP TABLE PacientData_24h;

DROP TABLE Analises_24h;
DROP TABLE Analises_24h_Final;
DROP TABLE Analises_24h_Media;
DROP TABLE Analises_24h_Organizado;
DROP TABLE Analises_DifData;
DROP TABLE Analises_Max24h;

DROP TABLE EscalaGlasgow_24h;
DROP TABLE EscalaGlasgow_24h_Media;
DROP TABLE EscalaGlasgow_24h_Organizado;
DROP TABLE EscalaGlasgow_DifData;
DROP TABLE EscalaGlasgow_Max24h;

DROP TABLE Gasimetrias_24h;
DROP TABLE Gasimetrias_24h_Final;
DROP TABLE Gasimetrias_24h_Media;
DROP TABLE Gasimetrias_24h_Organizado;
DROP TABLE Gasimetrias_DifData;
DROP TABLE Gasimetrias_Max24h;

DROP TABLE SinaisVitais_Enfermagem_24h;
DROP TABLE SinaisVitais_Enfermagem_24h_Final;
DROP TABLE SinaisVitais_Enfermagem_24h_Media;
DROP TABLE SinaisVitais_Enfermagem_24h_Organizado;
DROP TABLE SinaisVitais_Enfermagem_DifData;
DROP TABLE SinaisVitais_Enfermagem_Max24h;

DROP TABLE Diag_Antecedentes;
DROP TABLE Diag_Antecedentes_Final;
DROP TABLE Diag_Antecedentes_Organizado;
DROP TABLE Diag_Antecedentes_SemD;
DROP TABLE Diag_Antecedentes_Util;


-------------------------INTRODUCTION---------------------------------
-- When getting data into csv, put English (USA) and UTF-8 as character type


-- Constraints (e.g. keys, default values), however, are not copied
-- Creating a Table similar to Episodios
SELECT *
INTO PacientData_24h
FROM Episodios;

--DROP TABLE PacientData_PS;

-------------------------------Combining Important Data---------------------------------

-- Now lets combine and choose important data to have in our final dataset, each section will
-- add the information of a specific table to a copy of the main table of the dataset

------------------------SinaisVitais_Enfermagem-------------------------

-- adding the date of admission in UCI into a new table
-- SinaisVitais_Enfermagem_DifData
SELECT * INTO SinaisVitais_Enfermagem_DifData
FROM (SELECT d.*, ing.DataAdmissaoUnidade
	  FROM SinaisVitais_Enfermagem AS d
	  INNER JOIN Episodios AS ing
		  ON d.EpisodioKey = ing.[Key])
AS table1;

-- adding DifData as the difference in minutes
ALTER TABLE SinaisVitais_Enfermagem_DifData ADD DifData AS (DATEDIFF(minute, DataAdmissaoUnidade, [Data]));

--Now we can choose the timeframe to consider in the analysis

-- Here, starting at the minute 1440 after ICU entrance and ending at the minute 2880 after entrance
SELECT * INTO SinaisVitais_Enfermagem_Max24h
FROM (SELECT tbl.*
FROM SinaisVitais_Enfermagem_DifData tbl
WHERE DifData <= 2880 AND DifData > 1440)
AS table1;

-----------------------------------

SELECT * INTO SinaisVitais_Enfermagem_24h
FROM (SELECT tbl.*
FROM SinaisVitais_Enfermagem_Max24h tbl
  INNER JOIN
  (
    SELECT EpisodioKey, MAX([Data]) AS SVEnfermagemData, SinalVitalId
    FROM SinaisVitais_Enfermagem_Max24h
    GROUP BY EpisodioKey, SinalVitalId
  ) tbl1
  ON tbl1.EpisodioKey = tbl.EpisodioKey AND tbl1.SinalVitalId = tbl.SinalVitalId
WHERE tbl1.SVEnfermagemData = tbl.[DATA])
AS table1;

---------------------------------------

--Averaging vital signs that have the same first date
--And saving into SinaisVitais_Enfermagem_PS_Media
SELECT * INTO SinaisVitais_Enfermagem_24h_Media
FROM ( SELECT T1.EpisodioKey, T1.HospitalCodigo, T1.[Data], T1.SinalVitalId, AVG(T1.Valor) AS Valor 
FROM SinaisVitais_Enfermagem_24h T1
    JOIN SinaisVitais_Enfermagem_24h T2
	ON T1.EpisodioKey = T2.EpisodioKey AND T1.SinalVitalId = T2.SinalVitalId
GROUP BY T1.EpisodioKey, T1.SinalVitalId, T1.[Data], T1.HospitalCodigo )
AS table1;

ALTER TABLE SinaisVitais_Enfermagem_24h_Media
ADD SinalVitalDescr VARCHAR(8000)

-- Now join with the meaning of each SinalVitalId
UPDATE SinaisVitais_Enfermagem_24h_Media
    SET SinalVitalDescr = (
        SELECT SinalVitalDescr
        FROM 
		(
		SELECT EpisodioKey, SinalVitalId, Valor, ing.SinalVitalDescr
		FROM SinaisVitais_Enfermagem_24h_Media AS d
		INNER JOIN DimSinaisVitais AS ing
			ON d.SinalVitalId = ing.[Key]) AS tbl
        WHERE tbl.EpisodioKey = SinaisVitais_Enfermagem_24h_Media.EpisodioKey AND tbl.SinalVitalId = SinaisVitais_Enfermagem_24h_Media.SinalVitalId AND tbl.Valor = SinaisVitais_Enfermagem_24h_Media.Valor
    );

-- Eliminating some signs that have a low amount
DELETE FROM SinaisVitais_Enfermagem_24h_Media WHERE SinalVitalDescr='Temperatura Central/Esofágica' OR SinalVitalDescr='Temperatura Rectal';


--Now the step of merging the Episodios TAble with the Data we want
SELECT * INTO SinaisVitais_Enfermagem_24h_Organizado
FROM ( SELECT EpisodioKey,   
  FC, TAS, TAD, TAM, Temperatura, FR, SpO2, FiO2
FROM SinaisVitais_Enfermagem_24h_Media
PIVOT  
(  
  AVG(Valor)  
  FOR SinalVitalDescr IN (FC, TAS, TAD, TAM, Temperatura, FR, SpO2, FiO2)  
) AS PivotTable) 
AS table1; 


-- And now grouping by the episodio key
SELECT * INTO SinaisVitais_Enfermagem_24h_Final
FROM ( SELECT EpisodioKey,   
  SUM(FC) AS FC, SUM(TAS) AS TAS, SUM(TAD) AS TAD, SUM(TAM) AS TAM, SUM(Temperatura) AS Temperatura, SUM(FR) AS FR, SUM(SpO2) AS SpO2, SUM(FiO2) AS FiO2
FROM SinaisVitais_Enfermagem_24h_Organizado
GROUP BY EpisodioKey)
AS table1; 

-- add columns of SinaisVitais_Enfermagem_PS_Final into PacientData_PS
ALTER TABLE PacientData_24h
ADD FC DECIMAL(11,6), TAS DECIMAL(11,6), TAD DECIMAL(11,6), TAM DECIMAL(11,6),
Temperatura DECIMAL(11,6), FR DECIMAL(11,6), SpO2 DECIMAL(11,6), FiO2 DECIMAL(11,6);

--And finally adding the data to the main table
MERGE PacientData_24h AS t
USING SinaisVitais_Enfermagem_24h_Final  AS s
ON t.[Key] = s.EpisodioKey
WHEN MATCHED 
THEN UPDATE SET
t.FC = s.FC, t.TAS = s.TAS,
t.TAD = s.TAD, t.TAM = s.TAM, 
t.Temperatura = s.Temperatura,
t.FR = s.FR, t.SpO2 = s.SpO2, t.FiO2 = s.FiO2;
-- Done :)

------------------------Gasimetrias-------------------------

-- adding the date of admission in UCI
-- SinaisVitais_Enfermagem_DifData
SELECT * INTO Gasimetrias_DifData
FROM (SELECT d.*, ing.DataAdmissaoUnidade
	FROM Gasimetrias AS d
	INNER JOIN Episodios AS ing
		ON d.HospitalCodigo = ing.HospitalCodigo AND d.EpisodioDoenteId = ing.DoenteId AND d.EpisodioNumeroEpisodioHospitalar = ing.NumeroEpisodioHospitalar)
AS table1;

-- adding DifData as the difference in minutes
ALTER TABLE Gasimetrias_DifData ADD DifData AS (DATEDIFF(minute, DataAdmissaoUnidade, [Data]));

--Now we can choose the timeframe to consider in the analysis

-- Here, starting at the minute 1440 after ICU entrance and ending at the minute 2880 after entrance
SELECT * INTO Gasimetrias_Max24h
FROM (SELECT tbl.*
FROM Gasimetrias_DifData tbl
WHERE DifData <= 2880 AND DifData > 1440)
AS table1;

------------------------------------

SELECT * INTO Gasimetrias_24h
FROM (SELECT tbl.*
FROM Gasimetrias_Max24h tbl
  INNER JOIN
  (
    SELECT HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar, MAX([Data]) AS GasimetriasData, GasimetriaId
    FROM Gasimetrias_Max24h
    GROUP BY HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar, GasimetriaId
  ) tbl1
  ON tbl1.HospitalCodigo = tbl.HospitalCodigo AND tbl1.EpisodioDoenteId = tbl.EpisodioDoenteId AND tbl1.EpisodioNumeroEpisodioHospitalar = tbl.EpisodioNumeroEpisodioHospitalar AND tbl1.GasimetriaId = tbl.GasimetriaId
WHERE tbl1.GasimetriasData = tbl.[DATA])
AS table1;

-----

--Averaging vital signs that have the same first date
-- And saving into SinaisVitais_Enfermagem_PS_Media
SELECT * INTO Gasimetrias_24h_Media
FROM ( SELECT T1.HospitalCodigo, T1.EpisodioDoenteId, T1.EpisodioNumeroEpisodioHospitalar, T1.[Data], T1.GasimetriaId, AVG(T1.Valor) AS Valor 
FROM Gasimetrias_24h T1
    JOIN Gasimetrias_24h T2
	ON T1.HospitalCodigo = T2.HospitalCodigo AND T1.EpisodioDoenteId = T2.EpisodioDoenteId AND T1.EpisodioNumeroEpisodioHospitalar = T2.EpisodioNumeroEpisodioHospitalar AND T1.GasimetriaId = T2.GasimetriaId
GROUP BY T1.HospitalCodigo, T1.EpisodioDoenteId, T1.EpisodioNumeroEpisodioHospitalar, T1.GasimetriaId, T1.[Data] )
AS table1;

ALTER TABLE Gasimetrias_24h_Media
ADD GasimetriaDescrPT VARCHAR(8000)

--Now to update the meaning of the signals to the table
UPDATE Gasimetrias_24h_Media
    SET GasimetriaDescrPT = (
        SELECT GasimetriaDescrPT
        FROM 
		(
		SELECT HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar, GasimetriaId, ing.GasimetriaDescrPT, Valor
		FROM Gasimetrias_24h_Media AS d
		INNER JOIN DimGasimetrias AS ing
			ON d.GasimetriaId = ing.[Key]) AS tbl
        WHERE tbl.HospitalCodigo = Gasimetrias_24h_Media.HospitalCodigo AND tbl.EpisodioDoenteId = Gasimetrias_24h_Media.EpisodioDoenteId AND tbl.EpisodioNumeroEpisodioHospitalar = Gasimetrias_24h_Media.EpisodioNumeroEpisodioHospitalar AND tbl.GasimetriaId = Gasimetrias_24h_Media.GasimetriaId AND tbl.Valor = Gasimetrias_24h_Media.Valor
    );

--Now the step of merging the Episodios TAble with the Data we want
SELECT * INTO Gasimetrias_24h_Organizado
FROM ( SELECT HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar,   
  Lactacto, PaCO2, PaO2, pH, SaO2, Bicarbonato, metHb, BE, FiO2
FROM Gasimetrias_24h_Media
PIVOT  
(  
  AVG(Valor)  
  FOR GasimetriaDescrPT IN (Lactacto, PaCO2, PaO2, pH, SaO2, Bicarbonato, metHb, BE, FiO2)  
) AS PivotTable) 
AS table1; 

-- Now Grouping by the Episodio Key
-- And saving into SinaisVitais_Enfermagem_PS_Final
SELECT * INTO Gasimetrias_24h_Final
FROM ( SELECT HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar, 
  SUM(Lactacto) AS Lactacto, SUM(PaCO2) AS PaCO2, SUM(PaO2) AS PaO2, SUM(pH) AS pH, SUM(SaO2) AS SaO2, SUM(Bicarbonato) AS Bicarbonato, SUM(metHb) AS metHb, SUM(BE) AS BE, SUM(FiO2) AS FiO2
FROM Gasimetrias_24h_Organizado
GROUP BY HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar )
AS table1; 

--Change name of column FiO2 (there is already the same in the enfermangem signals data)
EXEC sp_rename 'Gasimetrias_24h_Final.FiO2', 'FiO2_Gasimetria';

-- add columns of SinaisVitais_Enfermagem_PS_Final into PacientData_PS
ALTER TABLE PacientData_24h
ADD Lactacto DECIMAL(11,6), PaCO2 DECIMAL(11,6), PaO2 DECIMAL(11,6), pH DECIMAL(11,6),
SaO2 DECIMAL(11,6), Bicarbonato DECIMAL(11,6), metHb DECIMAL(11,6), BE DECIMAL(11,6), FiO2_Gasimetria DECIMAL(11,6);

--And finally adding the data to the main table
MERGE PacientData_24h AS t
USING Gasimetrias_24h_Final  AS s
ON t.HospitalCodigo=s.HospitalCodigo AND t.DoenteId=s.EpisodioDoenteId AND t.NumeroEpisodioHospitalar=s.EpisodioNumeroEpisodioHospitalar
WHEN MATCHED 
THEN UPDATE SET
t.Lactacto = s.Lactacto, t.PaCO2 = s.PaCO2,
t.PaO2 = s.PaO2, t.pH = s.pH, 
t.SaO2 = s.SaO2, t.Bicarbonato = s.Bicarbonato,
t.metHb = s.metHb, t.BE = s.BE, t.FiO2_Gasimetria = s.FiO2_Gasimetria;
-- Done :)

------------------------Analises-------------------------

-- adding the date of admission in UCI
-- SinaisVitais_Enfermagem_DifData
SELECT * INTO Analises_DifData
FROM (SELECT d.*, ing.DataAdmissaoUnidade
	FROM Analises AS d
	INNER JOIN Episodios AS ing
		ON d.HospitalCodigo = ing.HospitalCodigo AND d.EpisodioDoenteId = ing.DoenteId AND d.EpisodioNumeroEpisodioHospitalar = ing.NumeroEpisodioHospitalar)
AS table1;

-- adding DifData as the difference in minutes
ALTER TABLE Analises_DifData ADD DifData AS (DATEDIFF(minute, DataAdmissaoUnidade, [Data]));

--Now we can choose the timeframe to consider in the analysis
-- Here, starting at the minute 1440 after ICU entrance and ending at the minute 2880 after entrance
SELECT * INTO Analises_Max24h
FROM (SELECT tbl.*
FROM Analises_DifData tbl
WHERE DifData <= 2880 AND DifData > 1440)
AS table1;

-----------------------------------

SELECT * INTO Analises_24h
FROM (SELECT tbl.*
FROM Analises_Max24h tbl
  INNER JOIN
  (
    SELECT HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar, MAX([Data]) AS AnalisesData, AnaliseId
    FROM Analises_Max24h
    GROUP BY HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar, AnaliseId
  ) tbl1
  ON tbl1.HospitalCodigo = tbl.HospitalCodigo AND tbl1.EpisodioDoenteId = tbl.EpisodioDoenteId AND tbl1.EpisodioNumeroEpisodioHospitalar = tbl.EpisodioNumeroEpisodioHospitalar AND tbl1.AnaliseId = tbl.AnaliseId
WHERE tbl1.AnalisesData = tbl.[DATA])
AS table1;

----

--Averaging vital signs that have the same first date
-- And saving
SELECT * INTO Analises_24h_Media
FROM ( SELECT T1.HospitalCodigo, T1.EpisodioDoenteId, T1.EpisodioNumeroEpisodioHospitalar, T1.[Data], T1.AnaliseId, AVG(T1.Valor) AS Valor 
FROM Analises_24h T1
    JOIN Analises_24h T2
	ON T1.HospitalCodigo = T2.HospitalCodigo AND T1.EpisodioDoenteId = T2.EpisodioDoenteId AND T1.EpisodioNumeroEpisodioHospitalar = T2.EpisodioNumeroEpisodioHospitalar AND T1.AnaliseId = T2.AnaliseId
GROUP BY T1.HospitalCodigo, T1.EpisodioDoenteId, T1.EpisodioNumeroEpisodioHospitalar, T1.AnaliseId, T1.[Data] )
AS table1;

ALTER TABLE Analises_24h_Media
ADD AnaliseDescrPT VARCHAR(8000)

-- Now join with the meaning of each Analisys
UPDATE Analises_24h_Media
    SET AnaliseDescrPT = (
        SELECT AnaliseDescrPT
        FROM 
		(
		SELECT HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar, AnaliseId, ing.AnaliseDescrPT, Valor
		FROM Analises_24h_Media AS d
		INNER JOIN DimAnalises AS ing
			ON d.AnaliseId = ing.[Key]) AS tbl
        WHERE tbl.HospitalCodigo = Analises_24h_Media.HospitalCodigo AND tbl.EpisodioDoenteId = Analises_24h_Media.EpisodioDoenteId AND tbl.EpisodioNumeroEpisodioHospitalar = Analises_24h_Media.EpisodioNumeroEpisodioHospitalar AND tbl.AnaliseId = Analises_24h_Media.AnaliseId AND tbl.Valor = Analises_24h_Media.Valor
    );




-- 1,25-vitamina D, bicarbonato and lactato has a very low amount
-- bicarbonato and lactato are already in other tables too...
DELETE FROM Analises_24h_Media WHERE AnaliseDescrPT='1,25-vitamina D' OR AnaliseDescrPT='Bicarbonato' OR AnaliseDescrPT='Lactato';


--Now the step of merging the Episodios TAble with the Data we want
SELECT * INTO Analises_24h_Organizado
FROM ( SELECT HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar,   
  [25-vitamina D], [Ácido fólico], [Ácido úrico], Albumina, [ALT/TGP], Amilase, Amónia, APTT, [AST/TGO], [Bilirrubina direta],
  [Bilirrubina total], BNP, [Cálcio corrigido], [Cálcio ionizado], [Cálcio total], CK, [CK-MB], [CK-MB massa], Cloro, 
  Creatinina, CTFF, [D-Dímeros], DHL, Ferritina, Ferro, Fibrinogénio, [Fosfatase alcalina], Fósforo, GGT, Glicose,
  Hemoglobina, [I.N.R], Leucócitos, Linfócitos, Lipase, Magnésio, Mioglobina, Neutrófilos, PCR, Plaquetas, Potássio,
  Procalcitonina, [Proteinas totais], Sódio, [Tempo de Protrombina], Transferrina, [Troponina I], [Troponina T], Ureia
FROM Analises_24h_Media
PIVOT  
(  
  AVG(Valor)  
  FOR AnaliseDescrPT IN ( [25-vitamina D], [Ácido fólico], [Ácido úrico], Albumina, [ALT/TGP], Amilase, Amónia, APTT, [AST/TGO], [Bilirrubina direta],
  [Bilirrubina total], BNP, [Cálcio corrigido], [Cálcio ionizado], [Cálcio total], CK, [CK-MB], [CK-MB massa], Cloro, 
  Creatinina, CTFF, [D-Dímeros], DHL, Ferritina, Ferro, Fibrinogénio, [Fosfatase alcalina], Fósforo, GGT, Glicose,
  Hemoglobina, [I.N.R], Leucócitos, Linfócitos, Lipase, Magnésio, Mioglobina, Neutrófilos, PCR, Plaquetas, Potássio,
  Procalcitonina, [Proteinas totais], Sódio, [Tempo de Protrombina], Transferrina, [Troponina I], [Troponina T], Ureia )  
) AS PivotTable) 
AS table1; 


-- And now grouping by the episodio key
SELECT * INTO Analises_24h_Final
FROM ( SELECT HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar, 
	SUM( [25-vitamina D] ) AS [25-vitamina D] , SUM( [Ácido fólico] ) AS [Ácido fólico] , SUM( [Ácido úrico] ) AS [Ácido úrico] , SUM( Albumina ) AS Albumina ,
	SUM( [ALT/TGP] ) AS [ALT/TGP] , SUM( Amilase ) AS Amilase , SUM( Amónia ) AS Amónia , SUM( APTT ) AS APTT , SUM( [AST/TGO] ) AS [AST/TGO] , 
	SUM( [Bilirrubina direta] ) AS [Bilirrubina direta] , SUM( [Bilirrubina total] ) AS [Bilirrubina total] , SUM( BNP ) AS BNP , SUM( [Cálcio corrigido] ) AS [Cálcio corrigido] ,
	SUM( [Cálcio ionizado] ) AS [Cálcio ionizado] , SUM( [Cálcio total] ) AS [Cálcio total] , SUM( CK ) AS CK , SUM( [CK-MB] ) AS [CK-MB] , SUM( [CK-MB massa] ) AS [CK-MB massa] ,
	SUM( Cloro ) AS Cloro , SUM( Creatinina ) AS Creatinina , SUM( CTFF ) AS CTFF , SUM( [D-Dímeros] ) AS [D-Dímeros] , SUM( DHL ) AS DHL , SUM( Ferritina ) AS Ferritina ,
	SUM( Ferro ) AS Ferro , SUM( Fibrinogénio ) AS Fibrinogénio , SUM( [Fosfatase alcalina] ) AS [Fosfatase alcalina] , SUM( Fósforo ) AS Fósforo , SUM( GGT ) AS GGT ,
	SUM( Glicose ) AS Glicose , SUM( Hemoglobina ) AS Hemoglobina , SUM( [I.N.R] ) AS [I.N.R] , SUM( Leucócitos ) AS Leucócitos , SUM( Linfócitos ) AS Linfócitos ,
	SUM( Lipase ) AS Lipase , SUM( Magnésio ) AS Magnésio , SUM( Mioglobina ) AS Mioglobina , SUM( Neutrófilos ) AS Neutrófilos , SUM( PCR ) AS PCR , SUM( Plaquetas ) AS Plaquetas ,
	SUM( Potássio ) AS Potássio , SUM( Procalcitonina ) AS Procalcitonina , SUM( [Proteinas totais] ) AS [Proteinas totais] , SUM( Sódio ) AS Sódio , SUM( [Tempo de Protrombina] ) AS [Tempo de Protrombina] ,
	SUM( Transferrina ) AS Transferrina , SUM( [Troponina I] ) AS [Troponina I] , SUM( [Troponina T] ) AS [Troponina T] , SUM( Ureia ) AS Ureia
FROM Analises_24h_Organizado
GROUP BY HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar )
AS table1; 

-- add columns of Analises_24h_Final into PacientData_PS
ALTER TABLE PacientData_24h
ADD [25-vitamina D] DECIMAL(20,10),  [Ácido fólico] DECIMAL(20,10),  [Ácido úrico] DECIMAL(20,10),  Albumina DECIMAL(20,10),
[ALT/TGP] DECIMAL(20,10),  Amilase DECIMAL(20,10),  Amónia DECIMAL(20,10),  APTT DECIMAL(20,10),  [AST/TGO] DECIMAL(20,10),
[Bilirrubina direta] DECIMAL(20,10),  [Bilirrubina total] DECIMAL(20,10),  BNP DECIMAL(20,10),  [Cálcio corrigido] DECIMAL(20,10),
[Cálcio ionizado] DECIMAL(20,10),  [Cálcio total] DECIMAL(20,10),  CK DECIMAL(20,10),  [CK-MB] DECIMAL(20,10),  [CK-MB massa] DECIMAL(20,10),
Cloro DECIMAL(20,10),  Creatinina DECIMAL(20,10),  CTFF DECIMAL(20,10),  [D-Dímeros] DECIMAL(20,10),  DHL DECIMAL(20,10),
Ferritina DECIMAL(20,10),  Ferro DECIMAL(20,10),  Fibrinogénio DECIMAL(20,10),  [Fosfatase alcalina] DECIMAL(20,10),  Fósforo DECIMAL(20,10),
GGT DECIMAL(20,10),  Glicose DECIMAL(20,10),  Hemoglobina DECIMAL(20,10),  [I.N.R] DECIMAL(20,10),  Leucócitos DECIMAL(20,10),
Linfócitos DECIMAL(20,10),  Lipase DECIMAL(20,10),  Magnésio DECIMAL(20,10),  Mioglobina DECIMAL(20,10),  Neutrófilos DECIMAL(20,10),
PCR DECIMAL(20,10),  Plaquetas DECIMAL(20,10),  Potássio DECIMAL(20,10),  Procalcitonina DECIMAL(20,10),  [Proteinas totais] DECIMAL(20,10),
Sódio DECIMAL(20,10),  [Tempo de Protrombina] DECIMAL(20,10),  Transferrina DECIMAL(20,10),  [Troponina I] DECIMAL(20,10),
[Troponina T] DECIMAL(20,10),  Ureia DECIMAL(20,10);

--And finally adding the data to the main table
MERGE PacientData_24h AS t
USING Analises_24h_Final  AS s
ON t.HospitalCodigo=s.HospitalCodigo AND t.DoenteId=s.EpisodioDoenteId AND t.NumeroEpisodioHospitalar=s.EpisodioNumeroEpisodioHospitalar
WHEN MATCHED 
THEN UPDATE SET
t.[25-vitamina D] = s.[25-vitamina D], t.[Ácido fólico] = s.[Ácido fólico], t.[Ácido úrico] = s.[Ácido úrico],
t.Albumina = s.Albumina, t.[ALT/TGP] = s.[ALT/TGP], t.Amilase = s.Amilase, t.Amónia = s.Amónia, t.APTT = s.APTT,
t.[AST/TGO] = s.[AST/TGO], t.[Bilirrubina direta] = s.[Bilirrubina direta], t.[Bilirrubina total] = s.[Bilirrubina total],
t.BNP = s.BNP, t.[Cálcio corrigido] = s.[Cálcio corrigido], t.[Cálcio ionizado] = s.[Cálcio ionizado], t.[Cálcio total] = s.[Cálcio total],
t.CK = s.CK, t.[CK-MB] = s.[CK-MB], t.[CK-MB massa] = s.[CK-MB massa], t.Cloro = s.Cloro, t.Creatinina = s.Creatinina, t.CTFF = s.CTFF,
t.[D-Dímeros] = s.[D-Dímeros], t.DHL = s.DHL, t.Ferritina = s.Ferritina, t.Ferro = s.Ferro, t.Fibrinogénio = s.Fibrinogénio,
t.[Fosfatase alcalina] = s.[Fosfatase alcalina], t.Fósforo = s.Fósforo, t.GGT = s.GGT, t.Glicose = s.Glicose, t.Hemoglobina = s.Hemoglobina,
t.[I.N.R] = s.[I.N.R], t.Leucócitos = s.Leucócitos, t.Linfócitos = s.Linfócitos, t.Lipase = s.Lipase, t.Magnésio = s.Magnésio,
t.Mioglobina = s.Mioglobina, t.Neutrófilos = s.Neutrófilos, t.PCR = s.PCR, t.Plaquetas = s.Plaquetas, t.Potássio = s.Potássio,
t.Procalcitonina = s.Procalcitonina, t.[Proteinas totais] = s.[Proteinas totais], t.Sódio = s.Sódio,
t.[Tempo de Protrombina] = s.[Tempo de Protrombina], t.Transferrina = s.Transferrina, t.[Troponina I] = s.[Troponina I],
t.[Troponina T] = s.[Troponina T], t.Ureia = s.Ureia;

-------------------- EscalaGlasgow ---------------------

-- adding the date of admission in UCI
SELECT * INTO EscalaGlasgow_DifData
FROM (SELECT d.*, ing.DataAdmissaoUnidade
	  FROM EscalaGlasgow AS d
	  INNER JOIN Episodios AS ing
		  ON d.EpisodioKey = ing.[Key])
AS table1;

-- adding DifData as the difference in minutes
ALTER TABLE EscalaGlasgow_DifData ADD DifData AS (DATEDIFF(minute, DataAdmissaoUnidade, [Data]));

--Now we can choose the timeframe to consider in the analysis

-- Here, starting at the minute 1440 after ICU entrance and ending at the minute 2880 after entrance
SELECT * INTO EscalaGlasgow_Max24h
FROM (SELECT tbl.*
FROM EscalaGlasgow_DifData tbl
WHERE DifData <= 2880 AND DifData > 1440)
AS table1;

-----------------------------------

SELECT * INTO EscalaGlasgow_24h
FROM (SELECT tbl.*
FROM EscalaGlasgow_Max24h tbl
  INNER JOIN
  (
    SELECT EpisodioKey, MAX([Data]) AS SVEnfermagemData
    FROM EscalaGlasgow_Max24h
    GROUP BY EpisodioKey
  ) tbl1
  ON tbl1.EpisodioKey = tbl.EpisodioKey 
WHERE tbl1.SVEnfermagemData = tbl.[DATA])
AS table1;

-----------------------

--Averaging signs that have the same first date
SELECT * INTO EscalaGlasgow_24h_Media
FROM ( SELECT T1.EpisodioKey, T1.HospitalCodigo, T1.[Data], AVG(T1.Score) AS Valor 
FROM EscalaGlasgow_24h T1
    JOIN EscalaGlasgow_24h T2
	ON T1.EpisodioKey = T2.EpisodioKey
GROUP BY T1.EpisodioKey, T1.[Data], T1.HospitalCodigo )
AS table1;

SELECT * INTO EscalaGlasgow_24h_Organizado
FROM ( SELECT EpisodioKey,   
  Valor AS GlasgowScore
FROM EscalaGlasgow_24h_Media )
AS table1;

-- add column into PacientData_PS
ALTER TABLE PacientData_24h
ADD GlasgowScore DECIMAL(11,6);

--And finally adding the data to the main table
MERGE PacientData_24h AS t
USING EscalaGlasgow_24h_Organizado  AS s
ON t.[Key] = s.EpisodioKey
WHEN MATCHED 
THEN UPDATE SET
t.GlasgowScore = s.GlasgowScore;

------------------------Diagnosticos-------------------------

-- choosing just antecedentes e associados
SELECT *
INTO Diag_AntecedentesPessoais
FROM Diagnosticos
WHERE ClassificacaoDiagnosticoId = 2 OR ClassificacaoDiagnosticoId = 3 OR ClassificacaoDiagnosticoId = 1;

ALTER TABLE Diag_AntecedentesPessoais
DROP COLUMN ClassificacaoDiagnosticoId, LineageKey, SourceKey, HospitalCodigo, [Key];

-- getting the meaning of the diagnostico
SELECT *
INTO Diag_Antecedentes
FROM (SELECT EpisodioKey, DiagnosticoId, ing.DiagnosticoDescr, map.CategorizacaoDiagnosticoId, cat.CategorizacaoDiagnosticosDescrPT
FROM Diag_AntecedentesPessoais AS d
INNER JOIN DimDiagnosticos AS ing
	ON d.DiagnosticoId = ing.[Key]
INNER JOIN DimCategorizacaoDiagnosticosMapeamento AS map
	ON ing.DiagnosticoDescr = map.DiagnosticoDescr
INNER JOIN DimCategorizacaoDiagnosticos as cat
	ON map.CategorizacaoDiagnosticoId = cat.[Key]) 
	AS d;

DROP TABLE Diag_AntecedentesPessoais;

-- eliminating duplicates
SELECT *
INTO Diag_Antecedentes_SemD
FROM (SELECT EpisodioKey, CategorizacaoDiagnosticosDescrPT
FROM Diag_Antecedentes) as t
GROUP BY t.EpisodioKey, t.CategorizacaoDiagnosticosDescrPT;

-------

-- Counting how many entrys for each antecedente description
SELECT CategorizacaoDiagnosticosDescrPT, COUNT(EpisodioKey) AS Amount
FROM Diag_Antecedentes_SemD
GROUP BY CategorizacaoDiagnosticosDescrPT
ORDER BY Amount;

--Diag_Antecedentes_Util just have the ones I think are usefull on a first analisys
SELECT *
INTO Diag_Antecedentes_Util
FROM Diag_Antecedentes_SemD
WHERE CategorizacaoDiagnosticosDescrPT = 'Hipertensão Arterial' OR CategorizacaoDiagnosticosDescrPT = 'Insuficiência Renal Aguda' OR CategorizacaoDiagnosticosDescrPT = 'Cardiopatia não Isquémica' OR CategorizacaoDiagnosticosDescrPT = 'Choque' OR CategorizacaoDiagnosticosDescrPT = 'Diabetes Mellitus' OR CategorizacaoDiagnosticosDescrPT = 'Arritmias Cardíacas' OR CategorizacaoDiagnosticosDescrPT = 'Dislipidemia' OR CategorizacaoDiagnosticosDescrPT = 'Tabagismo' OR CategorizacaoDiagnosticosDescrPT = 'Alcoolismo' OR CategorizacaoDiagnosticosDescrPT = 'Nefropatia / IRC' OR CategorizacaoDiagnosticosDescrPT = 'Sepsis' OR CategorizacaoDiagnosticosDescrPT = 'Coagulopatia' OR CategorizacaoDiagnosticosDescrPT = 'Patologia Cerebrovascular Hemorrágica' OR CategorizacaoDiagnosticosDescrPT = 'Patologia Cerebrovascular Hemorrágica' OR CategorizacaoDiagnosticosDescrPT = 'ITU' OR CategorizacaoDiagnosticosDescrPT = 'Obesidade' OR CategorizacaoDiagnosticosDescrPT = 'Traqueobronquite' OR CategorizacaoDiagnosticosDescrPT = 'Polineuropatia / Miopatia' OR CategorizacaoDiagnosticosDescrPT = 'Disfunção Multiorgânica' OR CategorizacaoDiagnosticosDescrPT='Anemia' OR CategorizacaoDiagnosticosDescrPT='VIH' OR CategorizacaoDiagnosticosDescrPT='Hemorragia Digestiva' OR CategorizacaoDiagnosticosDescrPT='Patologia Cerebrovascular Isquémica' OR CategorizacaoDiagnosticosDescrPT='Dependência / Intoxicação' OR CategorizacaoDiagnosticosDescrPT='Patologia Vascular' OR CategorizacaoDiagnosticosDescrPT='TVP/TEP' OR CategorizacaoDiagnosticosDescrPT='Pneumotórax' OR CategorizacaoDiagnosticosDescrPT='Abdómen Agudo' OR CategorizacaoDiagnosticosDescrPT='Patología Cerebrovascular' OR CategorizacaoDiagnosticosDescrPT='Coma' OR CategorizacaoDiagnosticosDescrPT='Alterações Ácido-base' OR CategorizacaoDiagnosticosDescrPT='Encefalopatia';

SELECT CategorizacaoDiagnosticosDescrPT, COUNT(EpisodioKey) AS Amount
FROM Diag_Antecedentes_Util
GROUP BY CategorizacaoDiagnosticosDescrPT
ORDER BY Amount;

ALTER TABLE Diag_Antecedentes_Util
ADD Valor int;

UPDATE Diag_Antecedentes_Util SET Valor = 1;

-----

--Now the step of merging the Episodios TAble with the Data we want
SELECT * INTO Diag_Antecedentes_Organizado
FROM ( SELECT EpisodioKey,   
	IsNull(VIH, 0) as VIH,
	IsNull([Hemorragia Digestiva], 0) as [Hemorragia Digestiva],
	IsNull([Patologia Cerebrovascular Isquémica], 0) as [Patologia Cerebrovascular Isquémica],
	IsNull([Dependência / Intoxicação], 0) as [Dependência / Intoxicação],
	IsNull([Patologia Vascular], 0) as [Patologia Vascular],
	IsNull([TVP/TEP], 0) as [TVP/TEP], IsNull(Pneumotórax, 0) as Pneumotórax,
	IsNull([Abdómen Agudo], 0) as [Abdómen Agudo], IsNull([Patología Cerebrovascular],
	0) as [Patología Cerebrovascular], IsNull(Coma, 0) as Coma,
	IsNull([Alterações Ácido-base], 0) as [Alterações Ácido-base],
	IsNull(Encefalopatia, 0) as Encefalopatia, IsNull(Anemia, 0) as Anemia,
	IsNull([Disfunção Multiorgânica], 0) as [Disfunção Multiorgânica],
	IsNull([Polineuropatia / Miopatia], 0) as [Polineuropatia / Miopatia],
	IsNull(Traqueobronquite, 0) as Traqueobronquite, IsNull(Obesidade, 0) as Obesidade,
	IsNull(ITU, 0) as ITU, IsNull([Patologia Cerebrovascular Hemorrágica], 0) as [Patologia Cerebrovascular Hemorrágica],
	IsNull(Coagulopatia, 0) as Coagulopatia, IsNull(Sepsis, 0) as Sepsis,
	IsNull([Nefropatia / IRC], 0) as [Nefropatia / IRC],
	IsNull(Alcoolismo, 0) as Alcoolismo, IsNull(Tabagismo, 0) as Tabagismo,
	IsNull(Dislipidemia, 0) as Dislipidemia, IsNull([Arritmias Cardíacas], 0) as [Arritmias Cardíacas],
	IsNull([Diabetes Mellitus], 0) as [Diabetes Mellitus], IsNull([Cardiopatia não Isquémica], 0) as [Cardiopatia não Isquémica],
	IsNull(Choque, 0) as Choque, IsNull([Insuficiência Renal Aguda], 0) as [Insuficiência Renal Aguda],
	IsNull([Hipertensão Arterial], 0) as [Hipertensão Arterial]
 FROM Diag_Antecedentes_Util
PIVOT  
(  
  AVG(Valor)  
  FOR CategorizacaoDiagnosticosDescrPT 
  IN (VIH, [Hemorragia Digestiva], [Patologia Cerebrovascular Isquémica],
  [Dependência / Intoxicação], [Patologia Vascular], [TVP/TEP], Pneumotórax,
  [Abdómen Agudo], [Patología Cerebrovascular], Coma, [Alterações Ácido-base],
  Encefalopatia, Anemia, [Disfunção Multiorgânica], [Polineuropatia / Miopatia],
  Traqueobronquite, Obesidade, ITU, [Patologia Cerebrovascular Hemorrágica],
  Coagulopatia, Sepsis, [Nefropatia / IRC], Alcoolismo, Tabagismo, Dislipidemia,
  [Arritmias Cardíacas], [Diabetes Mellitus], [Cardiopatia não Isquémica], Choque,
  [Insuficiência Renal Aguda], [Hipertensão Arterial])  
) AS PivotTable) 
AS table1; 


-- And now grouping by the episodio key
SELECT * INTO Diag_Antecedentes_Final
FROM ( SELECT EpisodioKey,   
  SUM(VIH) AS VIH, SUM([Hemorragia Digestiva]) AS [Hemorragia Digestiva],
  SUM([Patologia Cerebrovascular Isquémica]) AS [Patologia Cerebrovascular Isquémica],
  SUM([Dependência / Intoxicação]) AS [Dependência / Intoxicação],
  SUM([Patologia Vascular]) AS [Patologia Vascular], SUM([TVP/TEP]) AS [TVP/TEP],
  SUM(Pneumotórax) AS Pneumotórax, SUM([Abdómen Agudo]) AS [Abdómen Agudo],
  SUM([Patología Cerebrovascular]) AS [Patología Cerebrovascular], SUM(Coma) AS Coma,
  SUM([Alterações Ácido-base]) AS [Alterações Ácido-base], SUM(Encefalopatia) AS Encefalopatia,
  SUM(Anemia) AS Anemia, SUM([Disfunção Multiorgânica]) AS [Disfunção Multiorgânica], SUM([Polineuropatia / Miopatia]) AS [Polineuropatia / Miopatia],
  SUM(Traqueobronquite) AS Traqueobronquite, SUM(Obesidade) AS Obesidade, SUM(ITU) AS ITU,
  SUM([Patologia Cerebrovascular Hemorrágica]) AS [Patologia Cerebrovascular Hemorrágica],
  SUM(Coagulopatia) AS Coagulopatia, SUM(Sepsis) AS Sepsis, SUM([Nefropatia / IRC]) AS [Nefropatia / IRC],
  SUM(Alcoolismo) AS Alcoolismo, SUM(Tabagismo) AS Tabagismo, SUM(Dislipidemia) AS Dislipidemia,
  SUM([Arritmias Cardíacas]) AS [Arritmias Cardíacas], SUM([Diabetes Mellitus]) AS [Diabetes Mellitus],
  SUM([Cardiopatia não Isquémica]) AS [Cardiopatia não Isquémica], SUM(Choque) AS Choque,
  SUM([Insuficiência Renal Aguda]) AS [Insuficiência Renal Aguda],
  SUM([Hipertensão Arterial]) AS [Hipertensão Arterial] 
FROM Diag_Antecedentes_Organizado
GROUP BY EpisodioKey)
AS table1; 

-- add new columns into PacientData_24h
ALTER TABLE PacientData_24h
ADD VIH int, [Hemorragia Digestiva] int, [Patologia Cerebrovascular Isquémica] int,
[Dependência / Intoxicação] int, [Patologia Vascular] int, [TVP/TEP] int,
Pneumotórax int, [Abdómen Agudo] int, [Patología Cerebrovascular] int, Coma int,
[Alterações Ácido-base] int, Encefalopatia int, Anemia int, [Disfunção Multiorgânica] int,
[Polineuropatia / Miopatia] int, Traqueobronquite int, Obesidade int, ITU int,
[Patologia Cerebrovascular Hemorrágica] int, Coagulopatia int, Sepsis int,
[Nefropatia / IRC] int, Alcoolismo int, Tabagismo int, Dislipidemia int,
[Arritmias Cardíacas] int, [Diabetes Mellitus] int,
[Cardiopatia não Isquémica] int, Choque int, [Insuficiência Renal Aguda] int,
[Hipertensão Arterial] int;

--And finally adding the data to the main table
MERGE PacientData_24h AS t
USING Diag_Antecedentes_Final  AS s
ON t.[Key] = s.EpisodioKey
WHEN MATCHED 
THEN UPDATE SET
t.VIH = s.VIH, t.[Hemorragia Digestiva] = s.[Hemorragia Digestiva],
t.[Patologia Cerebrovascular Isquémica] = s.[Patologia Cerebrovascular Isquémica],
t.[Dependência / Intoxicação] = s.[Dependência / Intoxicação],
t.[Patologia Vascular] = s.[Patologia Vascular], t.[TVP/TEP] = s.[TVP/TEP],
t.Pneumotórax = s.Pneumotórax, t.[Abdómen Agudo] = s.[Abdómen Agudo],
t.[Patología Cerebrovascular] = s.[Patología Cerebrovascular], t.Coma = s.Coma,
t.[Alterações Ácido-base] = s.[Alterações Ácido-base], t.Encefalopatia = s.Encefalopatia,
t.Anemia = s.Anemia, t.[Disfunção Multiorgânica] = s.[Disfunção Multiorgânica],
t.[Polineuropatia / Miopatia] = s.[Polineuropatia / Miopatia], t.Traqueobronquite = s.Traqueobronquite,
t.Obesidade = s.Obesidade, t.ITU = s.ITU,
t.[Patologia Cerebrovascular Hemorrágica] = s.[Patologia Cerebrovascular Hemorrágica],
t.Coagulopatia = s.Coagulopatia, t.Sepsis = s.Sepsis, t.[Nefropatia / IRC] = s.[Nefropatia / IRC],
t.Alcoolismo = s.Alcoolismo, t.Tabagismo = s.Tabagismo, t.Dislipidemia = s.Dislipidemia,
t.[Arritmias Cardíacas] = s.[Arritmias Cardíacas], t.[Diabetes Mellitus] = s.[Diabetes Mellitus],
t.[Cardiopatia não Isquémica] = s.[Cardiopatia não Isquémica], t.Choque = s.Choque,
t.[Insuficiência Renal Aguda] = s.[Insuficiência Renal Aguda],
t.[Hipertensão Arterial] = s.[Hipertensão Arterial];

UPDATE PacientData_24h
SET VIH = 0, [Hemorragia Digestiva] = 0, [Patologia Cerebrovascular Isquémica] = 0,
[Dependência / Intoxicação] = 0, [Patologia Vascular] = 0, [TVP/TEP] = 0,
Pneumotórax = 0, [Abdómen Agudo] = 0, [Patología Cerebrovascular] = 0, Coma = 0,
[Alterações Ácido-base] = 0, Encefalopatia = 0, Anemia = 0,
[Disfunção Multiorgânica] = 0, [Polineuropatia / Miopatia] = 0,
Traqueobronquite = 0, Obesidade = 0, ITU = 0, [Patologia Cerebrovascular Hemorrágica] = 0,
Coagulopatia = 0, Sepsis = 0, [Nefropatia / IRC] = 0, Alcoolismo = 0,
Tabagismo = 0, Dislipidemia = 0, [Arritmias Cardíacas] = 0,
[Diabetes Mellitus] = 0, [Cardiopatia não Isquémica] = 0, Choque = 0,
[Insuficiência Renal Aguda] = 0, [Hipertensão Arterial] = 0
WHERE VIH IS NULL

-- Done :)