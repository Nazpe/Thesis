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
DELETE FROM SinaisVitais_Enfermagem_24h_Media WHERE SinalVitalDescr='Temperatura Central/Esof�gica' OR SinalVitalDescr='Temperatura Rectal';


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
  [25-vitamina D], [�cido f�lico], [�cido �rico], Albumina, [ALT/TGP], Amilase, Am�nia, APTT, [AST/TGO], [Bilirrubina direta],
  [Bilirrubina total], BNP, [C�lcio corrigido], [C�lcio ionizado], [C�lcio total], CK, [CK-MB], [CK-MB massa], Cloro, 
  Creatinina, CTFF, [D-D�meros], DHL, Ferritina, Ferro, Fibrinog�nio, [Fosfatase alcalina], F�sforo, GGT, Glicose,
  Hemoglobina, [I.N.R], Leuc�citos, Linf�citos, Lipase, Magn�sio, Mioglobina, Neutr�filos, PCR, Plaquetas, Pot�ssio,
  Procalcitonina, [Proteinas totais], S�dio, [Tempo de Protrombina], Transferrina, [Troponina I], [Troponina T], Ureia
FROM Analises_24h_Media
PIVOT  
(  
  AVG(Valor)  
  FOR AnaliseDescrPT IN ( [25-vitamina D], [�cido f�lico], [�cido �rico], Albumina, [ALT/TGP], Amilase, Am�nia, APTT, [AST/TGO], [Bilirrubina direta],
  [Bilirrubina total], BNP, [C�lcio corrigido], [C�lcio ionizado], [C�lcio total], CK, [CK-MB], [CK-MB massa], Cloro, 
  Creatinina, CTFF, [D-D�meros], DHL, Ferritina, Ferro, Fibrinog�nio, [Fosfatase alcalina], F�sforo, GGT, Glicose,
  Hemoglobina, [I.N.R], Leuc�citos, Linf�citos, Lipase, Magn�sio, Mioglobina, Neutr�filos, PCR, Plaquetas, Pot�ssio,
  Procalcitonina, [Proteinas totais], S�dio, [Tempo de Protrombina], Transferrina, [Troponina I], [Troponina T], Ureia )  
) AS PivotTable) 
AS table1; 


-- And now grouping by the episodio key
SELECT * INTO Analises_24h_Final
FROM ( SELECT HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar, 
	SUM( [25-vitamina D] ) AS [25-vitamina D] , SUM( [�cido f�lico] ) AS [�cido f�lico] , SUM( [�cido �rico] ) AS [�cido �rico] , SUM( Albumina ) AS Albumina ,
	SUM( [ALT/TGP] ) AS [ALT/TGP] , SUM( Amilase ) AS Amilase , SUM( Am�nia ) AS Am�nia , SUM( APTT ) AS APTT , SUM( [AST/TGO] ) AS [AST/TGO] , 
	SUM( [Bilirrubina direta] ) AS [Bilirrubina direta] , SUM( [Bilirrubina total] ) AS [Bilirrubina total] , SUM( BNP ) AS BNP , SUM( [C�lcio corrigido] ) AS [C�lcio corrigido] ,
	SUM( [C�lcio ionizado] ) AS [C�lcio ionizado] , SUM( [C�lcio total] ) AS [C�lcio total] , SUM( CK ) AS CK , SUM( [CK-MB] ) AS [CK-MB] , SUM( [CK-MB massa] ) AS [CK-MB massa] ,
	SUM( Cloro ) AS Cloro , SUM( Creatinina ) AS Creatinina , SUM( CTFF ) AS CTFF , SUM( [D-D�meros] ) AS [D-D�meros] , SUM( DHL ) AS DHL , SUM( Ferritina ) AS Ferritina ,
	SUM( Ferro ) AS Ferro , SUM( Fibrinog�nio ) AS Fibrinog�nio , SUM( [Fosfatase alcalina] ) AS [Fosfatase alcalina] , SUM( F�sforo ) AS F�sforo , SUM( GGT ) AS GGT ,
	SUM( Glicose ) AS Glicose , SUM( Hemoglobina ) AS Hemoglobina , SUM( [I.N.R] ) AS [I.N.R] , SUM( Leuc�citos ) AS Leuc�citos , SUM( Linf�citos ) AS Linf�citos ,
	SUM( Lipase ) AS Lipase , SUM( Magn�sio ) AS Magn�sio , SUM( Mioglobina ) AS Mioglobina , SUM( Neutr�filos ) AS Neutr�filos , SUM( PCR ) AS PCR , SUM( Plaquetas ) AS Plaquetas ,
	SUM( Pot�ssio ) AS Pot�ssio , SUM( Procalcitonina ) AS Procalcitonina , SUM( [Proteinas totais] ) AS [Proteinas totais] , SUM( S�dio ) AS S�dio , SUM( [Tempo de Protrombina] ) AS [Tempo de Protrombina] ,
	SUM( Transferrina ) AS Transferrina , SUM( [Troponina I] ) AS [Troponina I] , SUM( [Troponina T] ) AS [Troponina T] , SUM( Ureia ) AS Ureia
FROM Analises_24h_Organizado
GROUP BY HospitalCodigo, EpisodioDoenteId, EpisodioNumeroEpisodioHospitalar )
AS table1; 

-- add columns of Analises_24h_Final into PacientData_PS
ALTER TABLE PacientData_24h
ADD [25-vitamina D] DECIMAL(20,10),  [�cido f�lico] DECIMAL(20,10),  [�cido �rico] DECIMAL(20,10),  Albumina DECIMAL(20,10),
[ALT/TGP] DECIMAL(20,10),  Amilase DECIMAL(20,10),  Am�nia DECIMAL(20,10),  APTT DECIMAL(20,10),  [AST/TGO] DECIMAL(20,10),
[Bilirrubina direta] DECIMAL(20,10),  [Bilirrubina total] DECIMAL(20,10),  BNP DECIMAL(20,10),  [C�lcio corrigido] DECIMAL(20,10),
[C�lcio ionizado] DECIMAL(20,10),  [C�lcio total] DECIMAL(20,10),  CK DECIMAL(20,10),  [CK-MB] DECIMAL(20,10),  [CK-MB massa] DECIMAL(20,10),
Cloro DECIMAL(20,10),  Creatinina DECIMAL(20,10),  CTFF DECIMAL(20,10),  [D-D�meros] DECIMAL(20,10),  DHL DECIMAL(20,10),
Ferritina DECIMAL(20,10),  Ferro DECIMAL(20,10),  Fibrinog�nio DECIMAL(20,10),  [Fosfatase alcalina] DECIMAL(20,10),  F�sforo DECIMAL(20,10),
GGT DECIMAL(20,10),  Glicose DECIMAL(20,10),  Hemoglobina DECIMAL(20,10),  [I.N.R] DECIMAL(20,10),  Leuc�citos DECIMAL(20,10),
Linf�citos DECIMAL(20,10),  Lipase DECIMAL(20,10),  Magn�sio DECIMAL(20,10),  Mioglobina DECIMAL(20,10),  Neutr�filos DECIMAL(20,10),
PCR DECIMAL(20,10),  Plaquetas DECIMAL(20,10),  Pot�ssio DECIMAL(20,10),  Procalcitonina DECIMAL(20,10),  [Proteinas totais] DECIMAL(20,10),
S�dio DECIMAL(20,10),  [Tempo de Protrombina] DECIMAL(20,10),  Transferrina DECIMAL(20,10),  [Troponina I] DECIMAL(20,10),
[Troponina T] DECIMAL(20,10),  Ureia DECIMAL(20,10);

--And finally adding the data to the main table
MERGE PacientData_24h AS t
USING Analises_24h_Final  AS s
ON t.HospitalCodigo=s.HospitalCodigo AND t.DoenteId=s.EpisodioDoenteId AND t.NumeroEpisodioHospitalar=s.EpisodioNumeroEpisodioHospitalar
WHEN MATCHED 
THEN UPDATE SET
t.[25-vitamina D] = s.[25-vitamina D], t.[�cido f�lico] = s.[�cido f�lico], t.[�cido �rico] = s.[�cido �rico],
t.Albumina = s.Albumina, t.[ALT/TGP] = s.[ALT/TGP], t.Amilase = s.Amilase, t.Am�nia = s.Am�nia, t.APTT = s.APTT,
t.[AST/TGO] = s.[AST/TGO], t.[Bilirrubina direta] = s.[Bilirrubina direta], t.[Bilirrubina total] = s.[Bilirrubina total],
t.BNP = s.BNP, t.[C�lcio corrigido] = s.[C�lcio corrigido], t.[C�lcio ionizado] = s.[C�lcio ionizado], t.[C�lcio total] = s.[C�lcio total],
t.CK = s.CK, t.[CK-MB] = s.[CK-MB], t.[CK-MB massa] = s.[CK-MB massa], t.Cloro = s.Cloro, t.Creatinina = s.Creatinina, t.CTFF = s.CTFF,
t.[D-D�meros] = s.[D-D�meros], t.DHL = s.DHL, t.Ferritina = s.Ferritina, t.Ferro = s.Ferro, t.Fibrinog�nio = s.Fibrinog�nio,
t.[Fosfatase alcalina] = s.[Fosfatase alcalina], t.F�sforo = s.F�sforo, t.GGT = s.GGT, t.Glicose = s.Glicose, t.Hemoglobina = s.Hemoglobina,
t.[I.N.R] = s.[I.N.R], t.Leuc�citos = s.Leuc�citos, t.Linf�citos = s.Linf�citos, t.Lipase = s.Lipase, t.Magn�sio = s.Magn�sio,
t.Mioglobina = s.Mioglobina, t.Neutr�filos = s.Neutr�filos, t.PCR = s.PCR, t.Plaquetas = s.Plaquetas, t.Pot�ssio = s.Pot�ssio,
t.Procalcitonina = s.Procalcitonina, t.[Proteinas totais] = s.[Proteinas totais], t.S�dio = s.S�dio,
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
WHERE CategorizacaoDiagnosticosDescrPT = 'Hipertens�o Arterial' OR CategorizacaoDiagnosticosDescrPT = 'Insufici�ncia Renal Aguda' OR CategorizacaoDiagnosticosDescrPT = 'Cardiopatia n�o Isqu�mica' OR CategorizacaoDiagnosticosDescrPT = 'Choque' OR CategorizacaoDiagnosticosDescrPT = 'Diabetes Mellitus' OR CategorizacaoDiagnosticosDescrPT = 'Arritmias Card�acas' OR CategorizacaoDiagnosticosDescrPT = 'Dislipidemia' OR CategorizacaoDiagnosticosDescrPT = 'Tabagismo' OR CategorizacaoDiagnosticosDescrPT = 'Alcoolismo' OR CategorizacaoDiagnosticosDescrPT = 'Nefropatia / IRC' OR CategorizacaoDiagnosticosDescrPT = 'Sepsis' OR CategorizacaoDiagnosticosDescrPT = 'Coagulopatia' OR CategorizacaoDiagnosticosDescrPT = 'Patologia Cerebrovascular Hemorr�gica' OR CategorizacaoDiagnosticosDescrPT = 'Patologia Cerebrovascular Hemorr�gica' OR CategorizacaoDiagnosticosDescrPT = 'ITU' OR CategorizacaoDiagnosticosDescrPT = 'Obesidade' OR CategorizacaoDiagnosticosDescrPT = 'Traqueobronquite' OR CategorizacaoDiagnosticosDescrPT = 'Polineuropatia / Miopatia' OR CategorizacaoDiagnosticosDescrPT = 'Disfun��o Multiorg�nica' OR CategorizacaoDiagnosticosDescrPT='Anemia' OR CategorizacaoDiagnosticosDescrPT='VIH' OR CategorizacaoDiagnosticosDescrPT='Hemorragia Digestiva' OR CategorizacaoDiagnosticosDescrPT='Patologia Cerebrovascular Isqu�mica' OR CategorizacaoDiagnosticosDescrPT='Depend�ncia / Intoxica��o' OR CategorizacaoDiagnosticosDescrPT='Patologia Vascular' OR CategorizacaoDiagnosticosDescrPT='TVP/TEP' OR CategorizacaoDiagnosticosDescrPT='Pneumot�rax' OR CategorizacaoDiagnosticosDescrPT='Abd�men Agudo' OR CategorizacaoDiagnosticosDescrPT='Patolog�a Cerebrovascular' OR CategorizacaoDiagnosticosDescrPT='Coma' OR CategorizacaoDiagnosticosDescrPT='Altera��es �cido-base' OR CategorizacaoDiagnosticosDescrPT='Encefalopatia';

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
	IsNull([Patologia Cerebrovascular Isqu�mica], 0) as [Patologia Cerebrovascular Isqu�mica],
	IsNull([Depend�ncia / Intoxica��o], 0) as [Depend�ncia / Intoxica��o],
	IsNull([Patologia Vascular], 0) as [Patologia Vascular],
	IsNull([TVP/TEP], 0) as [TVP/TEP], IsNull(Pneumot�rax, 0) as Pneumot�rax,
	IsNull([Abd�men Agudo], 0) as [Abd�men Agudo], IsNull([Patolog�a Cerebrovascular],
	0) as [Patolog�a Cerebrovascular], IsNull(Coma, 0) as Coma,
	IsNull([Altera��es �cido-base], 0) as [Altera��es �cido-base],
	IsNull(Encefalopatia, 0) as Encefalopatia, IsNull(Anemia, 0) as Anemia,
	IsNull([Disfun��o Multiorg�nica], 0) as [Disfun��o Multiorg�nica],
	IsNull([Polineuropatia / Miopatia], 0) as [Polineuropatia / Miopatia],
	IsNull(Traqueobronquite, 0) as Traqueobronquite, IsNull(Obesidade, 0) as Obesidade,
	IsNull(ITU, 0) as ITU, IsNull([Patologia Cerebrovascular Hemorr�gica], 0) as [Patologia Cerebrovascular Hemorr�gica],
	IsNull(Coagulopatia, 0) as Coagulopatia, IsNull(Sepsis, 0) as Sepsis,
	IsNull([Nefropatia / IRC], 0) as [Nefropatia / IRC],
	IsNull(Alcoolismo, 0) as Alcoolismo, IsNull(Tabagismo, 0) as Tabagismo,
	IsNull(Dislipidemia, 0) as Dislipidemia, IsNull([Arritmias Card�acas], 0) as [Arritmias Card�acas],
	IsNull([Diabetes Mellitus], 0) as [Diabetes Mellitus], IsNull([Cardiopatia n�o Isqu�mica], 0) as [Cardiopatia n�o Isqu�mica],
	IsNull(Choque, 0) as Choque, IsNull([Insufici�ncia Renal Aguda], 0) as [Insufici�ncia Renal Aguda],
	IsNull([Hipertens�o Arterial], 0) as [Hipertens�o Arterial]
 FROM Diag_Antecedentes_Util
PIVOT  
(  
  AVG(Valor)  
  FOR CategorizacaoDiagnosticosDescrPT 
  IN (VIH, [Hemorragia Digestiva], [Patologia Cerebrovascular Isqu�mica],
  [Depend�ncia / Intoxica��o], [Patologia Vascular], [TVP/TEP], Pneumot�rax,
  [Abd�men Agudo], [Patolog�a Cerebrovascular], Coma, [Altera��es �cido-base],
  Encefalopatia, Anemia, [Disfun��o Multiorg�nica], [Polineuropatia / Miopatia],
  Traqueobronquite, Obesidade, ITU, [Patologia Cerebrovascular Hemorr�gica],
  Coagulopatia, Sepsis, [Nefropatia / IRC], Alcoolismo, Tabagismo, Dislipidemia,
  [Arritmias Card�acas], [Diabetes Mellitus], [Cardiopatia n�o Isqu�mica], Choque,
  [Insufici�ncia Renal Aguda], [Hipertens�o Arterial])  
) AS PivotTable) 
AS table1; 


-- And now grouping by the episodio key
SELECT * INTO Diag_Antecedentes_Final
FROM ( SELECT EpisodioKey,   
  SUM(VIH) AS VIH, SUM([Hemorragia Digestiva]) AS [Hemorragia Digestiva],
  SUM([Patologia Cerebrovascular Isqu�mica]) AS [Patologia Cerebrovascular Isqu�mica],
  SUM([Depend�ncia / Intoxica��o]) AS [Depend�ncia / Intoxica��o],
  SUM([Patologia Vascular]) AS [Patologia Vascular], SUM([TVP/TEP]) AS [TVP/TEP],
  SUM(Pneumot�rax) AS Pneumot�rax, SUM([Abd�men Agudo]) AS [Abd�men Agudo],
  SUM([Patolog�a Cerebrovascular]) AS [Patolog�a Cerebrovascular], SUM(Coma) AS Coma,
  SUM([Altera��es �cido-base]) AS [Altera��es �cido-base], SUM(Encefalopatia) AS Encefalopatia,
  SUM(Anemia) AS Anemia, SUM([Disfun��o Multiorg�nica]) AS [Disfun��o Multiorg�nica], SUM([Polineuropatia / Miopatia]) AS [Polineuropatia / Miopatia],
  SUM(Traqueobronquite) AS Traqueobronquite, SUM(Obesidade) AS Obesidade, SUM(ITU) AS ITU,
  SUM([Patologia Cerebrovascular Hemorr�gica]) AS [Patologia Cerebrovascular Hemorr�gica],
  SUM(Coagulopatia) AS Coagulopatia, SUM(Sepsis) AS Sepsis, SUM([Nefropatia / IRC]) AS [Nefropatia / IRC],
  SUM(Alcoolismo) AS Alcoolismo, SUM(Tabagismo) AS Tabagismo, SUM(Dislipidemia) AS Dislipidemia,
  SUM([Arritmias Card�acas]) AS [Arritmias Card�acas], SUM([Diabetes Mellitus]) AS [Diabetes Mellitus],
  SUM([Cardiopatia n�o Isqu�mica]) AS [Cardiopatia n�o Isqu�mica], SUM(Choque) AS Choque,
  SUM([Insufici�ncia Renal Aguda]) AS [Insufici�ncia Renal Aguda],
  SUM([Hipertens�o Arterial]) AS [Hipertens�o Arterial] 
FROM Diag_Antecedentes_Organizado
GROUP BY EpisodioKey)
AS table1; 

-- add new columns into PacientData_24h
ALTER TABLE PacientData_24h
ADD VIH int, [Hemorragia Digestiva] int, [Patologia Cerebrovascular Isqu�mica] int,
[Depend�ncia / Intoxica��o] int, [Patologia Vascular] int, [TVP/TEP] int,
Pneumot�rax int, [Abd�men Agudo] int, [Patolog�a Cerebrovascular] int, Coma int,
[Altera��es �cido-base] int, Encefalopatia int, Anemia int, [Disfun��o Multiorg�nica] int,
[Polineuropatia / Miopatia] int, Traqueobronquite int, Obesidade int, ITU int,
[Patologia Cerebrovascular Hemorr�gica] int, Coagulopatia int, Sepsis int,
[Nefropatia / IRC] int, Alcoolismo int, Tabagismo int, Dislipidemia int,
[Arritmias Card�acas] int, [Diabetes Mellitus] int,
[Cardiopatia n�o Isqu�mica] int, Choque int, [Insufici�ncia Renal Aguda] int,
[Hipertens�o Arterial] int;

--And finally adding the data to the main table
MERGE PacientData_24h AS t
USING Diag_Antecedentes_Final  AS s
ON t.[Key] = s.EpisodioKey
WHEN MATCHED 
THEN UPDATE SET
t.VIH = s.VIH, t.[Hemorragia Digestiva] = s.[Hemorragia Digestiva],
t.[Patologia Cerebrovascular Isqu�mica] = s.[Patologia Cerebrovascular Isqu�mica],
t.[Depend�ncia / Intoxica��o] = s.[Depend�ncia / Intoxica��o],
t.[Patologia Vascular] = s.[Patologia Vascular], t.[TVP/TEP] = s.[TVP/TEP],
t.Pneumot�rax = s.Pneumot�rax, t.[Abd�men Agudo] = s.[Abd�men Agudo],
t.[Patolog�a Cerebrovascular] = s.[Patolog�a Cerebrovascular], t.Coma = s.Coma,
t.[Altera��es �cido-base] = s.[Altera��es �cido-base], t.Encefalopatia = s.Encefalopatia,
t.Anemia = s.Anemia, t.[Disfun��o Multiorg�nica] = s.[Disfun��o Multiorg�nica],
t.[Polineuropatia / Miopatia] = s.[Polineuropatia / Miopatia], t.Traqueobronquite = s.Traqueobronquite,
t.Obesidade = s.Obesidade, t.ITU = s.ITU,
t.[Patologia Cerebrovascular Hemorr�gica] = s.[Patologia Cerebrovascular Hemorr�gica],
t.Coagulopatia = s.Coagulopatia, t.Sepsis = s.Sepsis, t.[Nefropatia / IRC] = s.[Nefropatia / IRC],
t.Alcoolismo = s.Alcoolismo, t.Tabagismo = s.Tabagismo, t.Dislipidemia = s.Dislipidemia,
t.[Arritmias Card�acas] = s.[Arritmias Card�acas], t.[Diabetes Mellitus] = s.[Diabetes Mellitus],
t.[Cardiopatia n�o Isqu�mica] = s.[Cardiopatia n�o Isqu�mica], t.Choque = s.Choque,
t.[Insufici�ncia Renal Aguda] = s.[Insufici�ncia Renal Aguda],
t.[Hipertens�o Arterial] = s.[Hipertens�o Arterial];

UPDATE PacientData_24h
SET VIH = 0, [Hemorragia Digestiva] = 0, [Patologia Cerebrovascular Isqu�mica] = 0,
[Depend�ncia / Intoxica��o] = 0, [Patologia Vascular] = 0, [TVP/TEP] = 0,
Pneumot�rax = 0, [Abd�men Agudo] = 0, [Patolog�a Cerebrovascular] = 0, Coma = 0,
[Altera��es �cido-base] = 0, Encefalopatia = 0, Anemia = 0,
[Disfun��o Multiorg�nica] = 0, [Polineuropatia / Miopatia] = 0,
Traqueobronquite = 0, Obesidade = 0, ITU = 0, [Patologia Cerebrovascular Hemorr�gica] = 0,
Coagulopatia = 0, Sepsis = 0, [Nefropatia / IRC] = 0, Alcoolismo = 0,
Tabagismo = 0, Dislipidemia = 0, [Arritmias Card�acas] = 0,
[Diabetes Mellitus] = 0, [Cardiopatia n�o Isqu�mica] = 0, Choque = 0,
[Insufici�ncia Renal Aguda] = 0, [Hipertens�o Arterial] = 0
WHERE VIH IS NULL

-- Done :)