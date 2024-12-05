-- 1. Jela ispod 15 eura
SELECT m.Name, m.Price
FROM MenuItems m
WHERE m.Price < 15
ORDER BY m.Price;

-- 2. Narudžbe iz 2023 iznad 50 eura
SELECT o.OrderID, o.OrderDate, o.TotalAmount
FROM Orders o
WHERE EXTRACT(YEAR FROM o.OrderDate) = 2023 
AND o.TotalAmount > 50
ORDER BY o.TotalAmount DESC;

-- 3. Dostavljači s više od 100 uspješno izvršenih dostava do danas
SELECT s.FirstName, s.LastName, COUNT(d.DeliveryID) as DeliveryCount
FROM Staff s
JOIN Deliveries d ON s.StaffID = d.StaffID
WHERE s.StaffType = 'Delivery'
GROUP BY s.StaffID, s.FirstName, s.LastName
HAVING COUNT(d.DeliveryID) > 100
ORDER BY DeliveryCount DESC;

-- 4. Kuhari koji rade u restoranima u Zagrebu
SELECT s.FirstName, s.LastName, r.Name as Restaurant
FROM Staff s
JOIN Restaurants r ON s.RestaurantID = r.RestaurantID
WHERE s.StaffType = 'Chef'
AND r.City = 'Zagreb';

-- 5. Broj narudžbi za svaki restoran u Splitu tijekom 2023. godine.
SELECT r.Name, COUNT(o.OrderID) as OrderCount
FROM Restaurants r
JOIN RestaurantMenuItem rm ON r.RestaurantID = rm.RestaurantID
JOIN OrderRestaurantMenuItem orm ON rm.RestaurantMenuItemID = orm.RestaurantMenuItemID
JOIN Orders o ON orm.OrderID = o.OrderID
WHERE r.City = 'Split'
AND EXTRACT(YEAR FROM o.OrderDate) = 2023
GROUP BY r.RestaurantID, r.Name
ORDER BY OrderCount DESC;

-- 6. Sva jela u kategoriji "Deserti" koja su naručena više od 10 puta u prosincu 2023.
SELECT m.Name, COUNT(orm.OrderRestaurantMenuItemID) as OrderCount
FROM MenuItems m
JOIN RestaurantMenuItem rm ON m.MenuItemID = rm.MenuItemID
JOIN OrderRestaurantMenuItem orm ON rm.RestaurantMenuItemID = orm.RestaurantMenuItemID
JOIN Orders o ON orm.OrderID = o.OrderID
WHERE m.Category = 'Desert'
AND EXTRACT(YEAR FROM o.OrderDate) = 2023
AND EXTRACT(MONTH FROM o.OrderDate) = 12
GROUP BY m.MenuItemID, m.Name
HAVING COUNT(orm.OrderRestaurantMenuItemID) > 10
ORDER BY OrderCount DESC;

-- 7. Broj narudžbi korisnika s prezimenom koje počinje na "M"
SELECT u.LastName, COUNT(o.OrderID) as OrderCount
FROM Users u
JOIN Orders o ON u.UserID = o.UserID
WHERE u.LastName LIKE 'M%'
GROUP BY u.UserID, u.LastName
ORDER BY OrderCount DESC;

-- 8. Prosječne ocjene za restorane u Rijeci
SELECT r.Name, ROUND(AVG(rt.Rating)::numeric, 2) as AvgRating
FROM Restaurants r
JOIN RestaurantMenuItem rm ON r.RestaurantID = rm.RestaurantID
JOIN OrderRestaurantMenuItem orm ON rm.RestaurantMenuItemID = orm.RestaurantMenuItemID
JOIN Ratings rt ON orm.OrderRestaurantMenuItemID = rt.OrderRestaurantMenuItemID
WHERE r.City = 'Rijeka'
GROUP BY r.RestaurantID, r.Name
ORDER BY AvgRating DESC;

-- 9. Restorani koji imaju kapacitet veći od 30 stolova i nude dostavu.
SELECT Name, TableCapacity
FROM Restaurants
WHERE TableCapacity > 30
AND OffersDelivery = TRUE
ORDER BY TableCapacity DESC;

-- 10. Uklonite iz jelovnika jela koja nisu naručena u posljednje 2 godine.
DELETE FROM MenuItems
WHERE MenuItemID IN (
    SELECT m.MenuItemID
    FROM MenuItems m
    LEFT JOIN RestaurantMenuItem rm ON m.MenuItemID = rm.MenuItemID
    LEFT JOIN OrderRestaurantMenuItem orm ON rm.RestaurantMenuItemID = orm.RestaurantMenuItemID
    LEFT JOIN Orders o ON orm.OrderID = o.OrderID
    GROUP BY m.MenuItemID
    HAVING MAX(o.OrderDate) < CURRENT_DATE - INTERVAL '2 years'
    OR MAX(o.OrderDate) IS NULL
);

-- 11. Brisanje loyalty kartica svih korisnika koji nisu naručili nijedno jelo u posljednjih godinu dana
DELETE FROM LoyaltyCards
WHERE UserID IN (
    SELECT u.UserID
    FROM Users u
    LEFT JOIN Orders o ON u.UserID = o.UserID
    GROUP BY u.UserID
    HAVING MAX(o.OrderDate) < CURRENT_DATE - INTERVAL '1 year'
    OR MAX(o.OrderDate) IS NULL
);