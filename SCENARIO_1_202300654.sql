-- ============================================================
-- SCENARIO 1: University Library Book Loans
-- ============================================================
--Clean up existing pbjectsnif any
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

--Create tables and insert sample data 
CREATE TABLE books (
book_id SERIAL PRIMARY KEY,
title VARCHAR (100) NOT NULL,
available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INT REFERENCES books(book_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    status VARCHAR(20) DEFAULT 'ISSUED' -- 'ISSUED' or 'RETURNED'
);

INSERT INTO books (title, available_copies) VALUES
('Database System Concepts', 5),
('Advanced PostgreSQL', 1),
('Operating Systems', 0);

--2. IF ELSIF ELSE demo
DO $$
DECLARE 
  v_copies INT;
  v_title VARCHAR(100);
BEGIN
    SELECT title, available_copies INTO v_title, v_copies FROM books WHERE book_id = 1;

	IF v_copies = 0 THEN
	    RAISE NOTICE 'Book "%" is unvailable.', v_title;
	ELSIF v_copies < 3 THEN
	    RAISE NOTICE  'Book "%" is low on copies(% remaining).', v_title, v_copies;
	ELSE
	    RAISE NOTICE 'Book "%" is sufficiently stocked (% remaining ).', v_title, v_copies;
	END IF;
END $$;	

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE 
    v_counter INT := 1;
BEGIN 
    --WHILE loop for overdue reminders 
	WHILE v_counter <= 3 LOOP
	    RAISE NOTICE 'Overdue Reminder Number: %', v_counter;
		v_counter := v_counter + 1;
	END LOOP;
	--- Numeric FOR loop for shelf numbers
	FOR i IN 1..3 LOOP
	     RAISE NOTICE 'Library shelf Number: %', i;
	END LOOP;
END $$;

-- 4. Create borrow_book procedure 
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INT,
	p_student_number VARCHAR(20),
	p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE 
    v_available INT;
BEGIN
    IF p_quantity <= 0 THEN
	   RAISE EXCEPTION 'Invalid loan quantity: %', p_quantity;
	END IF;

	SELECT available_copies INTO v_available 
	FROM books
	WHERE book_id = p_book_id FOR UPDATE;

	IF v_available IS NULL THEN 
	   RAISE EXCEPTION 'Book ID % does not exist.', p_book_id;
	ELSIF v_available < p_quantity THEN 
	   RAISE NOTICE 'Loan rejected: Requested % copies, but only % available for book ID %.', p_quantity, v_available, p_book_id;
	ELSE   
	   UPDATE books
	   SET available_copies = available_copies - p_quantity
	   WHERE book_id = p_book_id;

	   INSERT INTO book_loans (book_id, student_number, quantity, status)
	   VALUES (p_book_id, p_student_number, p_quantity, 'ISSUED');

	   RAISE NOTICE 'Loan successful: % copies borrowed for student %.', p_quantity, p_student_number;
	END IF;
END;
$$;

--5. Call borrow_book procedure (2 valid, 1 exceeding )
CALL borrow_book(1, '20230001', 2); --valid
CALL borrow_book(2,'20230002', 1); --valid
CALL borrow_book(1, '20230003', 10); -- Exceeds stock

SELECT * FROM books;
SELECT * FROM book_loans;

--6. Create return_book procedure
CREATE OR REPLACE PROCEDURE return_book(
    p_loan_id INT
)
LANGUAGE plpgsql 
AS $$
DECLARE 
     v_status VARCHAR(20);
	 v_book_id INT;
	 v_quantity INT;
BEGIN
    SELECT status, book_id, quantity INTO v_status, v_book_id, v_quantity
	FROM book_loans
	WHERE loan_id = p_loan_id FOR UPDATE;
    IF v_status IS NULL THEN
        RAISE NOTICE 'Loan ID % not found.', p_loan_id;
    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan ID % is already returned. Stock will not be updated again.', p_loan_id;
    ELSE
        UPDATE book_loans SET status = 'RETURNED' WHERE loan_id = p_loan_id;
        UPDATE books SET available_copies = available_copies + v_quantity WHERE book_id = v_book_id;
        RAISE NOTICE 'Loan ID % successfully returned.', p_loan_id;
    END IF;
END;
$$;

-- Call return_book twice on same loan
CALL return_book(1);
CALL return_book(1); -- Idempotent test

-- 7. Explicit cursor for books with few copies remaining
DO $$
DECLARE
    cur_low_stock CURSOR FOR 
        SELECT book_id, title, available_copies FROM books WHERE available_copies <= 2;
    v_rec RECORD;
BEGIN
    OPEN cur_low_stock;
    LOOP
        FETCH cur_low_stock INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Stock Book -> ID: %, Title: %, Copies: %', v_rec.book_id, v_rec.title, v_rec.available_copies;
    END LOOP;
    CLOSE cur_low_stock;
END $$;

-- 8. Try to borrow zero copies with EXCEPTION handling
DO $$
BEGIN
    CALL borrow_book(1, '20230004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught expected exception: %', SQLERRM;
END $$;

-- 9. Final verification queries
SELECT * FROM books;
SELECT * FROM book_loans;	