-- ============================================================
-- SCENARIO 4: Campus Clinic Medicine Dispensing
-- ============================================================

DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;

-- 1. Create tables and insert sample data
CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INT REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    status VARCHAR(20) DEFAULT 'DISPENSED' -- 'DISPENSED' or 'REVERSED'
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
('Paracetamol 500mg', 100),
('Amoxicillin 250mg', 5),
('Ibuprofen 400mg', 0);

-- 2. IF ELSIF ELSE demo
DO $$
DECLARE
    v_stock INT;
    v_med VARCHAR(100);
BEGIN
    SELECT medicine_name, stock_quantity INTO v_med, v_stock FROM medicines WHERE medicine_id = 2;
    
    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine % is out of stock.', v_med;
    ELSIF v_stock <= 10 THEN
        RAISE NOTICE 'Medicine % is low on stock (% left).', v_med, v_stock;
    ELSE
        RAISE NOTICE 'Medicine % is sufficiently stocked (% left).', v_med, v_stock;
    END IF;
END $$;

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_rev INT := 1;
BEGIN
    -- WHILE loop
    WHILE v_rev <= 3 LOOP
        RAISE NOTICE 'Stock Review Day %', v_rev;
        v_rev := v_rev + 1;
    END LOOP;

    -- FOR loop
    FOR insp IN 1..3 LOOP
        RAISE NOTICE 'Shelf Inspection Number %', insp;
    END LOOP;
END $$;

-- 4. Create dispense_medicine procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INT,
    p_student_number VARCHAR(20),
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Dispensing quantity must be greater than zero. Provided: %', p_quantity;
    END IF;

    SELECT stock_quantity INTO v_stock 
    FROM medicines 
    WHERE medicine_id = p_medicine_id FOR UPDATE;

    IF v_stock IS NULL THEN
        RAISE EXCEPTION 'Medicine ID % not found.', p_medicine_id;
    ELSIF v_stock < p_quantity THEN
        RAISE NOTICE 'Dispensing failed: Stock is %, requested %.', v_stock, p_quantity;
    ELSE
        UPDATE medicines 
        SET stock_quantity = stock_quantity - p_quantity 
        WHERE medicine_id = p_medicine_id;

        INSERT INTO dispensing_records (medicine_id, student_number, quantity, status)
        VALUES (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

        RAISE NOTICE 'Dispensed % units to student %.', p_quantity, p_student_number;
    END IF;
END;
$$;

-- 5. Call dispense_medicine
CALL dispense_medicine(1, '20232001', 10); -- Valid
CALL dispense_medicine(2, '20232002', 3);  -- Valid
CALL dispense_medicine(2, '20232003', 50); -- Exceeds stock

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- 6. Create reverse_dispensing procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(
    p_record_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_med_id INT;
    v_qty INT;
BEGIN
    SELECT status, medicine_id, quantity INTO v_status, v_med_id, v_qty
    FROM dispensing_records 
    WHERE record_id = p_record_id FOR UPDATE;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Dispensing record ID % not found.', p_record_id;
    ELSIF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record ID % is already reversed. Stock restored only once.', p_record_id;
    ELSE
        UPDATE dispensing_records SET status = 'REVERSED' WHERE record_id = p_record_id;
        UPDATE medicines SET stock_quantity = stock_quantity + v_qty WHERE medicine_id = v_med_id;
        RAISE NOTICE 'Dispensing record ID % successfully reversed.', p_record_id;
    END IF;
END;
$$;

-- Call reverse_dispensing twice
CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

-- 7. Explicit cursor for medicines below low-stock threshold (threshold <= 10)
DO $$
DECLARE
    cur_med CURSOR FOR 
        SELECT medicine_id, medicine_name, stock_quantity FROM medicines WHERE stock_quantity <= 10;
    v_rec RECORD;
BEGIN
    OPEN cur_med;
    LOOP
        FETCH cur_med INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Stock Medicine -> Name: %, Stock: %', v_rec.medicine_name, v_rec.stock_quantity;
    END LOOP;
    CLOSE cur_med;
END $$;

-- 8. Negative quantity request with EXCEPTION handling
DO $$
BEGIN
    CALL dispense_medicine(1, '20232004', -5);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught expected exception: %', SQLERRM;
END $$;

-- 9. Final state verification
SELECT * FROM medicines;
SELECT * FROM dispensing_records;