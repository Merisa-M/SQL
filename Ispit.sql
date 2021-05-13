CREATE DATABASE Ispit_2019_06_24
USE Ispit_2019_06_24

CREATE TABLE Narudzba
(
	NarudzbaID INT CONSTRAINT PK_Narudzba PRIMARY KEY (NarudzbaID),
	Kupac NVARCHAR (40),
	PunaAdresa NVARCHAR (80),
	DatumNarudzbe DATE,
	Prevoz MONEY, 
	Uposlenik NVARCHAR (40), 
	GradUposlenika NVARCHAR (30), 
	DatumZaposlenja DATE,
	BrGodStaza INT
)

CREATE TABLE Proizvod
(
	ProizvodID INT CONSTRAINT PK_ProizvodID PRIMARY KEY (ProizvodID),
	NazivProizvoda NVARCHAR (40),
	NazivDobavljaca NVARCHAR (40),
	StanjeNaSklad INT,
	NarucenaKol INT
)

CREATE TABLE DetaljiNarudzbe
(
	NarudzbaID INT not null,
	ProizvodID INT not null,
	CijenaProizvoda MONEY,
	Kolicina INT not null,
	Popust REAL,
	CONSTRAINT FK_Detalji_Narudzba FOREIGN KEY (NarudzbaID) REFERENCES Narudzba (NarudzbaID),
	CONSTRAINT FK_Detalji_Proizvod FOREIGN KEY (ProizvodID) REFERENCES Proizvod (ProizvodID),
	CONSTRAINT PK_DetaljiNarudzbe PRIMARY KEY (NarudzbaID, ProizvodID)
)

INSERT INTO Narudzba 
SELECT	O.OrderID, C.CompanyName, C.Address + ' - ' + C.PostalCode + ' - ' + C.City,
		O.OrderDate, O.Freight, 
		E.LastName + ' ' + E.FirstName, E.City, E.HireDate, DATEDIFF (YEAR, E.HireDate, GETDATE ()) 
FROM	Northwind.dbo.Customers AS C INNER JOIN Northwind.dbo.Orders AS O
ON		C.CustomerID = O.CustomerID 
		INNER JOIN Northwind.dbo.Employees AS E
		ON O.EmployeeID = E.EmployeeID


SELECT * FROM Narudzba


INSERT INTO Proizvod
SELECT	P.ProductID, P.ProductName, S.CompanyName, P.UnitsInStock, P.UnitsOnOrder
FROM	Northwind.dbo.Products AS P INNER JOIN Northwind.dbo.Suppliers AS S 
ON		P.SupplierID = S.SupplierID
WHERE	P.ProductID IN
(SELECT P.ProductID 
FROM Northwind.dbo.Products)



INSERT INTO DetaljiNarudzbe
SELECT	OD.OrderID, OD.ProductID, FLOOR (OD.UnitPrice), OD.Quantity, OD.Discount
FROM    Northwind.dbo.[Order Details] AS OD INNER JOIN Northwind.dbo.Products AS P
ON		OD.ProductID = P.ProductID


ALTER TABLE Narudzba
ADD SifraUposlenika NVARCHAR (20) CONSTRAINT CK_Sifra CHECK (LEN (SifraUposlenika) = 15)


UPDATE Narudzba
SET SifraUposlenika = LEFT (REVERSE (GradUposlenika + ' ' + CONVERT (NVARCHAR (10), DatumZaposlenja)), 15)

select * from Narudzba


--BRISANJE OGRANICENJA NA SifraUposlenika
alter table Narudzba
drop constraint CK_Sifra
--ili
alter table Narudzba
drop constraint 

--ZAMJENA SVIH VRIJEDNOSTI SifraUposlenika KOJIMA NAZIV GRADA ZAVRŠAVA SLOVOM D
UPDATE Narudzba
SET SifraUposlenika = LEFT (NEWID(), 20)
WHERE right (GradUposlenika, 1) LIKE ('%d')


select * from Narudzba



CREATE VIEW view_SifraUposlenika AS
SELECT	N.Uposlenik, N.SifraUposlenika, COUNT (P.NazivProizvoda) AS UkupnoProdatihProizvoda
FROM	Narudzba AS N INNER JOIN DetaljiNarudzbe AS DN
ON		DN.NarudzbaID = N.NarudzbaID
		INNER JOIN Proizvod AS P
		ON DN.ProizvodID = P.ProizvodID
WHERE	LEN (N.SifraUposlenika) = 20
GROUP BY N.Uposlenik, N.SifraUposlenika
HAVING COUNT (P.NazivProizvoda) > 2

SELECT * FROM view_SifraUposlenika
ORDER BY 3 DESC




CREATE PROCEDURE sifra_Narudzbe AS
BEGIN 
UPDATE Narudzba
SET SifraUposlenika = LEFT (NEWID (), 4)
WHERE LEN (SifraUposlenika) = 20
END

EXEC sifra_Narudzbe


CREATE VIEW view_Ukupno AS
SELECT	P.NazivProizvoda, ROUND (SUM (DN.CijenaProizvoda * DN.Kolicina * (1- DN.Popust)), 2) AS Ukupno
FROM	DetaljiNarudzbe AS DN INNER JOIN Proizvod AS P
ON		DN.ProizvodID = P.ProizvodID
WHERE	P.NarucenaKol > 0
GROUP BY P.NazivProizvoda
HAVING	ROUND (SUM (DN.CijenaProizvoda * DN.Kolicina * (1- DN.Popust)), 2) > 10000

SELECT * FROM view_Ukupno
ORDER BY 2 desc

CREATE VIEW view_sr_vrij_cijene AS
SELECT	N.Kupac, P.NazivProizvoda, SUM (DN.CijenaProizvoda) AS SumaPoCijeni
FROM	DetaljiNarudzbe AS DN INNER JOIN Narudzba AS N
ON		DN.NarudzbaID = N.NarudzbaID 
		INNER JOIN Proizvod AS P
		ON DN.ProizvodID = P.ProizvodID
WHERE	DN.CijenaProizvoda >
		(SELECT AVG (CijenaProizvoda) FROM DetaljiNarudzbe)
GROUP BY N.Kupac, P.NazivProizvoda

SELECT * FROM view_sr_vrij_cijene
order by 3


CREATE PROCEDURE sp_sr_vrij_cijene 
(
	@Kupac NVARCHAR (40) = NULL,
	@NazivProizvoda NVARCHAR (40) = NULL,
	@SumaPoCijeni MONEY = NULL
)
AS
BEGIN
	SELECT Kupac, NazivProizvoda, SumaPoCijeni 
	FROM view_sr_vrij_cijene
	WHERE	SumaPoCijeni > (SELECT AVG (SumaPoCijeni) FROM view_sr_vrij_cijene) AND 
			Kupac = @Kupac OR
			NazivProizvoda = @NazivProizvoda OR
			SumaPoCijeni = @SumaPoCijeni
	ORDER BY 3
END

EXEC sp_sr_vrij_cijene @SumaPoCijeni = 123
EXEC sp_sr_vrij_cijene @Kupac = 'Hanari Carnes'
EXEC sp_sr_vrij_cijene @NazivProizvoda = 'Côte de Blaye'


CREATE NONCLUSTERED INDEX IX_StanjeNaSklad ON Proizvod
(
		NazivDobavljaca ASC
)
INCLUDE (StanjeNaSklad, NarucenaKol)

SELECT * FROM Proizvod
WHERE NazivDobavljaca = 'Pavlova, Ltd.' AND StanjeNaSklad > 10 AND NarucenaKol < 10

alter index [IX_StanjeNaSklad] 
on Proizvod
disable

/*Napraviti backup baze podataka na default lokaciju servera.*/
BACKUP DATABASE Ispit_2019_06_24 
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\Backup\Ispit_2019_06_24.bak'

--ili
BACKUP DATABASE Ispit_2019_06_24 
TO DISK = 'Ispit_2019_06_24.bak'

/*Kreirati proceduru kojom će se u jednom pokretanju izvršiti brisanje svih pogleda i procedura koji su kreirani u Vašoj bazi.*/
CREATE PROCEDURE brisanje 
AS
BEGIN
	DROP VIEW [dbo].[view_SifraUposlenika]
	DROP VIEW [dbo].[view_Ukupno]
	DROP VIEW [dbo].[view_sr_vrij_cijene]
	DROP PROCEDURE [dbo].[sifra_Narudzbe]
	DROP PROCEDURE [dbo].[sp_sr_vrij_cijene]
END

EXEC brisanje