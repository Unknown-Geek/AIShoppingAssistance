-- Synthetic Order Data to simulate purchase regularity
-- Insert into the table that tracks user carts/orders (e.g., 'user_carts')

-- =======================================================================
-- User A (760f1105-bd02-4459-9a91-f39959531378)
-- Pattern: Buys Lay's C&O (QLS-0004) and Boost (QLS-0027) every ~10 days
-- =======================================================================

INSERT INTO user_carts (user_id, items, total_price, status, created_at, updated_at) VALUES
('760f1105-bd02-4459-9a91-f39959531378', '[{"id":"1781453481521","name":"Lay''s American Style Cream and Onion Chips","price":20,"details":"SKU: QLS-0004 • ₹20.00","quantity":2},{"id":"1781453511849","name":"Boost Health Drink","price":255,"details":"SKU: QLS-0027 • ₹255.00","quantity":1}]', 295, 'processed', '2026-03-20 10:00:00+00', '2026-03-20 10:30:00+00'),
('760f1105-bd02-4459-9a91-f39959531378', '[{"id":"1781453481522","name":"Lay''s American Style Cream and Onion Chips","price":20,"details":"SKU: QLS-0004 • ₹20.00","quantity":2},{"id":"1781453511850","name":"Boost Health Drink","price":255,"details":"SKU: QLS-0027 • ₹255.00","quantity":1}]', 295, 'processed', '2026-03-30 10:00:00+00', '2026-03-30 10:30:00+00'),
('760f1105-bd02-4459-9a91-f39959531378', '[{"id":"1781453481523","name":"Lay''s American Style Cream and Onion Chips","price":20,"details":"SKU: QLS-0004 • ₹20.00","quantity":1},{"id":"1781453511851","name":"Boost Health Drink","price":255,"details":"SKU: QLS-0027 • ₹255.00","quantity":1}]', 275, 'processed', '2026-04-10 10:00:00+00', '2026-04-10 10:30:00+00'),
('760f1105-bd02-4459-9a91-f39959531378', '[{"id":"1781453481524","name":"Lay''s American Style Cream and Onion Chips","price":20,"details":"SKU: QLS-0004 • ₹20.00","quantity":2},{"id":"1781453511852","name":"Boost Health Drink","price":255,"details":"SKU: QLS-0027 • ₹255.00","quantity":1}]', 295, 'processed', '2026-04-22 10:00:00+00', '2026-04-22 10:30:00+00'),
('760f1105-bd02-4459-9a91-f39959531378', '[{"id":"1781453481525","name":"Lay''s American Style Cream and Onion Chips","price":20,"details":"SKU: QLS-0004 • ₹20.00","quantity":2},{"id":"1781453511853","name":"Boost Health Drink","price":255,"details":"SKU: QLS-0027 • ₹255.00","quantity":1}]', 295, 'processed', '2026-05-02 10:00:00+00', '2026-05-02 10:30:00+00'),
('760f1105-bd02-4459-9a91-f39959531378', '[{"id":"1781453481526","name":"Lay''s American Style Cream and Onion Chips","price":20,"details":"SKU: QLS-0004 • ₹20.00","quantity":1},{"id":"1781453511854","name":"Boost Health Drink","price":255,"details":"SKU: QLS-0027 • ₹255.00","quantity":1}]', 275, 'processed', '2026-05-12 10:00:00+00', '2026-05-12 10:30:00+00'),
('760f1105-bd02-4459-9a91-f39959531378', '[{"id":"1781453481527","name":"Lay''s American Style Cream and Onion Chips","price":20,"details":"SKU: QLS-0004 • ₹20.00","quantity":3},{"id":"1781453511855","name":"Boost Health Drink","price":255,"details":"SKU: QLS-0027 • ₹255.00","quantity":1}]', 315, 'processed', '2026-05-24 10:00:00+00', '2026-05-24 10:30:00+00'),
('760f1105-bd02-4459-9a91-f39959531378', '[{"id":"1781453481528","name":"Lay''s American Style Cream and Onion Chips","price":20,"details":"SKU: QLS-0004 • ₹20.00","quantity":2},{"id":"1781453511856","name":"Boost Health Drink","price":255,"details":"SKU: QLS-0027 • ₹255.00","quantity":1}]', 295, 'processed', '2026-06-03 10:00:00+00', '2026-06-03 10:30:00+00');


-- =======================================================================
-- User B (d5777910-84ac-4ac9-84a0-0819ad960378)
-- Pattern: Buys Softer Bar (QLS-0013) and Lay's Masala (QLS-0030) every ~14 days
-- =======================================================================

INSERT INTO user_carts (user_id, items, total_price, status, created_at, updated_at) VALUES
('d5777910-84ac-4ac9-84a0-0819ad960378', '[{"id":"1781453481621","name":"Softer Bar Chocolate Bar","price":30,"details":"SKU: QLS-0013 • ₹30.00","quantity":2},{"id":"1781453511949","name":"Lay''s India''s Magic Masala Chips","price":20,"details":"SKU: QLS-0030 • ₹20.00","quantity":3}]', 120, 'processed', '2026-03-15 12:00:00+00', '2026-03-15 12:30:00+00'),
('d5777910-84ac-4ac9-84a0-0819ad960378', '[{"id":"1781453481622","name":"Softer Bar Chocolate Bar","price":30,"details":"SKU: QLS-0013 • ₹30.00","quantity":2},{"id":"1781453511950","name":"Lay''s India''s Magic Masala Chips","price":20,"details":"SKU: QLS-0030 • ₹20.00","quantity":3}]', 120, 'processed', '2026-03-29 12:00:00+00', '2026-03-29 12:30:00+00'),
('d5777910-84ac-4ac9-84a0-0819ad960378', '[{"id":"1781453481623","name":"Softer Bar Chocolate Bar","price":30,"details":"SKU: QLS-0013 • ₹30.00","quantity":1},{"id":"1781453511951","name":"Lay''s India''s Magic Masala Chips","price":20,"details":"SKU: QLS-0030 • ₹20.00","quantity":2}]', 70, 'processed', '2026-04-12 12:00:00+00', '2026-04-12 12:30:00+00'),
('d5777910-84ac-4ac9-84a0-0819ad960378', '[{"id":"1781453481624","name":"Softer Bar Chocolate Bar","price":30,"details":"SKU: QLS-0013 • ₹30.00","quantity":2},{"id":"1781453511952","name":"Lay''s India''s Magic Masala Chips","price":20,"details":"SKU: QLS-0030 • ₹20.00","quantity":3}]', 120, 'processed', '2026-04-26 12:00:00+00', '2026-04-26 12:30:00+00'),
('d5777910-84ac-4ac9-84a0-0819ad960378', '[{"id":"1781453481625","name":"Softer Bar Chocolate Bar","price":30,"details":"SKU: QLS-0013 • ₹30.00","quantity":3},{"id":"1781453511953","name":"Lay''s India''s Magic Masala Chips","price":20,"details":"SKU: QLS-0030 • ₹20.00","quantity":4}]', 170, 'processed', '2026-05-10 12:00:00+00', '2026-05-10 12:30:00+00'),
('d5777910-84ac-4ac9-84a0-0819ad960378', '[{"id":"1781453481626","name":"Softer Bar Chocolate Bar","price":30,"details":"SKU: QLS-0013 • ₹30.00","quantity":2},{"id":"1781453511954","name":"Lay''s India''s Magic Masala Chips","price":20,"details":"SKU: QLS-0030 • ₹20.00","quantity":2}]', 100, 'processed', '2026-05-25 12:00:00+00', '2026-05-25 12:30:00+00'),
('d5777910-84ac-4ac9-84a0-0819ad960378', '[{"id":"1781453481627","name":"Softer Bar Chocolate Bar","price":30,"details":"SKU: QLS-0013 • ₹30.00","quantity":2},{"id":"1781453511955","name":"Lay''s India''s Magic Masala Chips","price":20,"details":"SKU: QLS-0030 • ₹20.00","quantity":3}]', 120, 'processed', '2026-06-08 12:00:00+00', '2026-06-08 12:30:00+00');
