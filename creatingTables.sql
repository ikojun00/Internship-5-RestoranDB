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
    Category VARCHAR(20) CHECK (Category IN ('Appetizer', 'Main Course', 'Dessert', 'Beverage')),
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
    UserID INT REFERENCES Users(UserID) UNIQUE,
);

CREATE TABLE Orders (
    OrderID SERIAL PRIMARY KEY,
    UserID INT REFERENCES Users(UserID),
    OrderDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    OrderType VARCHAR(20) CHECK (OrderType IN ('Delivery', 'Dine-in')),
    TotalAmount DECIMAL(10,2) NOT NULL CHECK (TotalAmount >= 0)
);

DELETE FROM Orders;

CREATE TRIGGER validate_delivery_type
BEFORE INSERT OR UPDATE ON Orders
FOR EACH ROW
EXECUTE FUNCTION check_delivery_type();

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

CREATE TABLE OrderRestaurantMenuItem (
    OrderRestaurantMenuItemID SERIAL PRIMARY KEY,
    OrderID INT REFERENCES Orders(OrderID),
    RestaurantMenuItemID INT REFERENCES RestaurantMenuItem(RestaurantMenuItemID),
    Quantity INT NOT NULL CHECK (Quantity > 0)
);

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
-- treba popraviti ovo
CREATE TABLE Deliveries (
    DeliveryID SERIAL PRIMARY KEY,
    OrderID INT REFERENCES Orders(OrderID) UNIQUE,
    StaffID INT REFERENCES Staff(StaffID),
    DeliveryAddress VARCHAR(200) NOT NULL,
    DeliveryTime TIMESTAMP,
    CustomerNotes TEXT
);

CREATE TABLE Ratings (
    RatingID SERIAL PRIMARY KEY,
	OrderRestaurantMenuItem INT REFERENCES OrderRestaurantMenuItem(OrderRestaurantMenuItemID) UNIQUE,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    Comment TEXT
);