CREATE TABLE Restaurants (
    RestaurantID SERIAL PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    City VARCHAR(50) NOT NULL,
    TableCapacity INT NOT NULL CHECK (TableCapacity > 0),
    OpeningTime TIME NOT NULL,
    ClosingTime TIME NOT NULL,
    OffersDelivery BOOLEAN DEFAULT TRUE,
    CHECK (OpeningTime < ClosingTime)
);

CREATE TABLE MenuItems (
    MenuItemID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Category VARCHAR(20) CHECK (Category IN ('Piće', 'Glavno jelo', 'Desert', 'Predjelo')),
    Price DECIMAL(10,2) NOT NULL CHECK (Price > 0),
    Calories INT CHECK (Calories > 0)
);

CREATE TABLE RestaurantMenuItem (
	RestaurantMenuItemID SERIAL PRIMARY KEY,
    RestaurantID INT REFERENCES Restaurants(RestaurantID),
    MenuItemID INT REFERENCES MenuItems(MenuItemID)
);

CREATE TABLE Users (
    UserID SERIAL PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Phone VARCHAR(20)
);

CREATE TABLE LoyaltyCards (
    LoyaltyCardID SERIAL PRIMARY KEY,
    UserID INT REFERENCES Users(UserID) UNIQUE
);

-- kreira sam funkciju insert_eligible_loyalty_cards (functions.sql) koja na temelju zadanih kriterija dodaje
-- korisnike u loyaltyCards + doda sam par novih korisnika koji ne zadovoljavaju uvjete zbog 11. upita
-- opisani podatci su u dokumentu loyaltyCards.csv koji je u folderu seeds 
CREATE OR REPLACE FUNCTION insert_eligible_loyalty_cards()
RETURNS INTEGER AS $$
DECLARE
    inserted_count INTEGER := 0;
BEGIN
    -- dodavanje korisnika u loyalty cards
    INSERT INTO LoyaltyCards (UserID)
    SELECT 
        u.UserID
    FROM Users u
    WHERE NOT EXISTS (
        -- ako nisu već u tablici loyaltyCards
        SELECT 1 
        FROM LoyaltyCards lc 
        WHERE lc.UserID = u.UserID
    )
    AND (
        -- ako imaju više od 15 narudžbi
        SELECT COUNT(*) 
        FROM Orders o 
        WHERE o.UserID = u.UserID
    ) > 15
    AND (
		-- ako je ukupna vrijednost narudžbi veće od 1000 eura
        SELECT COALESCE(SUM(TotalAmount), 0) 
        FROM Orders o 
        WHERE o.UserID = u.UserID
    ) > 1000;

    -- Get number of rows inserted
    GET DIAGNOSTICS inserted_count = ROW_COUNT;

    -- Return number of loyalty cards inserted
    RETURN inserted_count;
END;
$$ LANGUAGE plpgsql;

SELECT insert_eligible_loyalty_cards();

CREATE OR REPLACE FUNCTION check_delivery_type()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.OrderType = 'Delivery' THEN
        IF EXISTS (
            SELECT 1
            FROM Orders o
            JOIN OrderRestaurantMenuItem orm ON o.OrderID = orm.OrderID
            JOIN RestaurantMenuItem rm ON orm.RestaurantMenuItemID = rm.RestaurantMenuItemID
            JOIN Restaurants r ON rm.RestaurantID = r.RestaurantID
            WHERE o.OrderID = NEW.OrderID
            AND r.OffersDelivery = FALSE
        ) THEN
            RAISE EXCEPTION 'Restaurant does not offer delivery service';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_delivery_type
BEFORE INSERT OR UPDATE ON Orders
FOR EACH ROW
EXECUTE FUNCTION check_delivery_type();

CREATE TABLE Orders (
    OrderID SERIAL PRIMARY KEY,
    UserID INT REFERENCES Users(UserID),
    OrderDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    OrderType VARCHAR(20) CHECK (OrderType IN ('Delivery', 'Dine-in')),
    TotalAmount DECIMAL(10,2) NOT NULL CHECK (TotalAmount >= 0)
);

-- želimo dohvatiti jela koja restoran ima, ne sva moguća
CREATE TABLE OrderRestaurantMenuItem (
    OrderRestaurantMenuItemID SERIAL PRIMARY KEY,
    OrderID INT REFERENCES Orders(OrderID),
    RestaurantMenuItemID INT REFERENCES RestaurantMenuItem(RestaurantMenuItemID),
    Quantity INT NOT NULL CHECK (Quantity > 0)
);

CREATE OR REPLACE FUNCTION validate_staff()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.StaffType = 'Delivery' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM Restaurants
            WHERE RestaurantID = NEW.RestaurantID
            AND OffersDelivery = TRUE
        ) THEN
            RAISE EXCEPTION 'Delivery staff cannot be assigned to a restaurant that does not offer delivery.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_staff
BEFORE INSERT OR UPDATE ON Staff
FOR EACH ROW
EXECUTE FUNCTION validate_staff();

CREATE TABLE Staff (
    StaffID SERIAL PRIMARY KEY,
    RestaurantID INT REFERENCES Restaurants(RestaurantID),
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    DateOfBirth DATE NOT NULL,
    StaffType VARCHAR(10) CHECK (StaffType IN ('Chef', 'Waiter', 'Delivery')),
    DriversLicense BOOLEAN DEFAULT FALSE
);

ALTER TABLE Staff
ADD CONSTRAINT check_chef_age 
CHECK (
    (StaffType = 'Chef' AND 
     DateOfBirth <= CURRENT_DATE - INTERVAL '18 years')
    OR StaffType != 'Chef'
);

ALTER TABLE Staff
ADD CONSTRAINT check_delivery_license 
CHECK (
    (StaffType = 'Delivery' AND DriversLicense = TRUE)
    OR StaffType != 'Delivery'
);

CREATE TABLE Deliveries (
    DeliveryID SERIAL PRIMARY KEY,
    OrderID INT REFERENCES Orders(OrderID) UNIQUE,
    StaffID INT REFERENCES Staff(StaffID),
    DeliveryAddress VARCHAR(200) NOT NULL,
    CustomerNotes TEXT
);

CREATE OR REPLACE FUNCTION check_delivery_order_type()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Orders 
        WHERE OrderID = NEW.OrderID 
        AND OrderType = 'Delivery'
    ) THEN
        RAISE EXCEPTION 'Order must be of type delivery';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_delivery_order_type
BEFORE INSERT OR UPDATE ON Deliveries
FOR EACH ROW
EXECUTE FUNCTION check_delivery_order_type();

CREATE OR REPLACE FUNCTION check_delivery_staff()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM Staff s
        JOIN Restaurants r ON s.RestaurantID = r.RestaurantID
        JOIN RestaurantMenuItem rm ON r.RestaurantID = rm.RestaurantID
        JOIN OrderRestaurantMenuItem orm ON rm.RestaurantMenuItemID = orm.RestaurantMenuItemID
        WHERE s.StaffID = NEW.StaffID 
        AND s.StaffType = 'Delivery'
        AND orm.OrderID = NEW.OrderID
    ) THEN
        RAISE EXCEPTION 'Staff member must be delivery type and work in restaurant that received the order';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_valid_delivery_staff
BEFORE INSERT OR UPDATE ON Deliveries
FOR EACH ROW
EXECUTE FUNCTION check_delivery_staff();

CREATE TABLE Ratings (
    RatingID SERIAL PRIMARY KEY,
	OrderRestaurantMenuItemID INT REFERENCES OrderRestaurantMenuItem(OrderRestaurantMenuItemID) UNIQUE,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    Comment TEXT
);