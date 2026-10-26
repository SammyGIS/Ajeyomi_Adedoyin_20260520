-- ==============================================================================
-- SQL Data Loading Script (PostgreSQL COPY)
-- Organization: Adedoyin Mobility and Logistics
-- Student Name: Adedoyin Ajeyomi
-- Student ID:   20260520
-- Description:  Copies operational CSV data from data/ directory into the 8 tables
-- ==============================================================================

-- 1. Stations
\copy stations(station_id, station_name, state, address, contact_phone, manager_name) FROM 'data/stations.csv' WITH (FORMAT csv, HEADER true);

-- 2. Vehicles
\copy vehicles(vehicle_id, registration_number, chassis_number, make_model, seating_capacity, current_station_id, roadworthiness_expiry, gps_tracker_id, status) FROM 'data/vehicles.csv' WITH (FORMAT csv, HEADER true);

-- 3. Drivers
\copy drivers(driver_id, full_name, phone_number, nin, license_number, license_expiry, assigned_vehicle_id, status) FROM 'data/drivers.csv' WITH (FORMAT csv, HEADER true);

-- 4. Customers
\copy customers(customer_id, full_name, phone_number, email, nin, emergency_contact_name, emergency_contact_phone) FROM 'data/customers.csv' WITH (FORMAT csv, HEADER true);

-- 5. Routes
\copy routes(route_id, origin_station_id, destination_station_id, distance_km, est_travel_hours, base_passenger_fare, base_parcel_rate) FROM 'data/routes.csv' WITH (FORMAT csv, HEADER true);

-- 6. Trips
\copy trips(trip_id, route_id, vehicle_id, driver_id, departure_datetime, arrival_datetime, trip_status) FROM 'data/trips.csv' WITH (FORMAT csv, HEADER true);

-- 7. Bookings
\copy bookings(booking_id, trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference, booking_timestamp) FROM 'data/bookings.csv' WITH (FORMAT csv, HEADER true);

-- 8. Parcels
\copy parcels(parcel_id, trip_id, sender_customer_id, recipient_name, recipient_phone, recipient_nin, waybill_number, weight_kg, declared_value, delivery_status) FROM 'data/parcels.csv' WITH (FORMAT csv, HEADER true);

-- Reset serial identity sequences to current max ID
SELECT setval('stations_station_id_seq', (SELECT MAX(station_id) FROM stations));
SELECT setval('vehicles_vehicle_id_seq', (SELECT MAX(vehicle_id) FROM vehicles));
SELECT setval('drivers_driver_id_seq', (SELECT MAX(driver_id) FROM drivers));
SELECT setval('customers_customer_id_seq', (SELECT MAX(customer_id) FROM customers));
SELECT setval('routes_route_id_seq', (SELECT MAX(route_id) FROM routes));
SELECT setval('trips_trip_id_seq', (SELECT MAX(trip_id) FROM trips));
SELECT setval('bookings_booking_id_seq', (SELECT MAX(booking_id) FROM bookings));
SELECT setval('parcels_parcel_id_seq', (SELECT MAX(parcel_id) FROM parcels));
