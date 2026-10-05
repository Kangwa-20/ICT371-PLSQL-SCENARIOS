-- ============================================================
-- SCENARIO 6: University Event Seat Booking
-- ============================================================

DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS events CASCADE;

-- 1. Create tables and insert sample data
CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    available_seats INT NOT NULL CHECK (available_seats >= 0)
);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    event_id INT REFERENCES events(event_id),
    student_number VARCHAR(20) NOT NULL,
    num_seats INT NOT NULL CHECK (num_seats > 0),
    status VARCHAR(20) DEFAULT 'BOOKED' -- 'BOOKED' or 'CANCELLED'
);

INSERT INTO events (event_name, available_seats) VALUES
('Graduation Gala Night', 100),
('Annual Hackathon', 3),
('Career Fair Keynote', 0);

-- 2. IF ELSIF ELSE demo
DO $$
DECLARE
    v_seats INT;
    v_event VARCHAR(100);
BEGIN
    SELECT event_name, available_seats INTO v_event, v_seats FROM events WHERE event_id = 2;
    
    IF v_seats = 0 THEN
        RAISE NOTICE 'Event "%" is full.', v_event;
    ELSIF v_seats <= 5 THEN
        RAISE NOTICE 'Event "%" is nearly full (% seats remaining).', v_event, v_seats;
    ELSE
        RAISE NOTICE 'Event "%" has plenty of seats (% available).', v_event, v_seats;
    END IF;
END $$;

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_day INT := 1;
BEGIN
    -- WHILE loop
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Booking Reminder Day %', v_day;
        v_day := v_day + 1;
    END LOOP;

    -- FOR loop
    FOR entrance IN 1..3 LOOP
        RAISE NOTICE 'Entrance Check Number %', entrance;
    END LOOP;
END $$;

-- 4. Create book_seats procedure
CREATE OR REPLACE PROCEDURE book_seats(
    p_event_id INT,
    p_student_number VARCHAR(20),
    p_seats INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_seats INT;
BEGIN
    IF p_seats <= 0 THEN
        RAISE EXCEPTION 'Number of seats to book must be greater than zero.';
    END IF;

    SELECT available_seats INTO v_seats 
    FROM events 
    WHERE event_id = p_event_id FOR UPDATE;

    IF v_seats IS NULL THEN
        RAISE EXCEPTION 'Event ID % not found.', p_event_id;
    ELSIF v_seats < p_seats THEN
        RAISE NOTICE 'Booking failed: Requested % seats, but only % remain.', p_seats, v_seats;
    ELSE
        UPDATE events 
        SET available_seats = available_seats - p_seats 
        WHERE event_id = p_event_id;

        INSERT INTO bookings (event_id, student_number, num_seats, status)
        VALUES (p_event_id, p_student_number, p_seats, 'BOOKED');

        RAISE NOTICE 'Booked % seat(s) for student %.', p_seats, p_student_number;
    END IF;
END;
$$;

-- 5. Call book_seats
CALL book_seats(1, '20234001', 4); -- Valid
CALL book_seats(2, '20234002', 2); -- Valid
CALL book_seats(2, '20234003', 10); -- Exceeds remaining seats

SELECT * FROM events;
SELECT * FROM bookings;

-- 6. Create cancel_booking procedure
CREATE OR REPLACE PROCEDURE cancel_booking(
    p_booking_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_event_id INT;
    v_seats INT;
BEGIN
    SELECT status, event_id, num_seats INTO v_status, v_event_id, v_seats
    FROM bookings 
    WHERE booking_id = p_booking_id FOR UPDATE;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Booking ID % not found.', p_booking_id;
    ELSIF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking ID % is already cancelled. Seats will not be released again.', p_booking_id;
    ELSE
        UPDATE bookings SET status = 'CANCELLED' WHERE booking_id = p_booking_id;
        UPDATE events SET available_seats = available_seats + v_seats WHERE event_id = v_event_id;
        RAISE NOTICE 'Booking ID % successfully cancelled.', p_booking_id;
    END IF;
END;
$$;

-- Call cancel_booking twice
CALL cancel_booking(1);
CALL cancel_booking(1);

-- 7. Explicit cursor for full or nearly full events
DO $$
DECLARE
    cur_events CURSOR FOR 
        SELECT event_id, event_name, available_seats FROM events WHERE available_seats <= 5;
    v_rec RECORD;
BEGIN
    OPEN cur_events;
    LOOP
        FETCH cur_events INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/Nearly Full Event -> % (Seats Left: %)', v_rec.event_name, v_rec.available_seats;
    END LOOP;
    CLOSE cur_events;
END $$;

-- 8. Try to book zero seats with EXCEPTION block
DO $$
BEGIN
    CALL book_seats(1, '20234004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught expected exception: %', SQLERRM;
END $$;

-- 9. Final state query
SELECT * FROM events;
SELECT * FROM bookings;