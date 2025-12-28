-- Kit Products Table
CREATE TABLE IF NOT EXISTS kit_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL, -- 'male', 'female', 'hoodie'
  product_name TEXT NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  stripe_url TEXT NOT NULL,
  stock_xs INTEGER DEFAULT 0,
  stock_s INTEGER DEFAULT 0,
  stock_m INTEGER DEFAULT 0,
  stock_l INTEGER DEFAULT 0,
  stock_xl INTEGER DEFAULT 0,
  stock_xxl INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_kit_products_category ON kit_products(category);

-- Enable Row Level Security
ALTER TABLE kit_products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "kit_products_select_all" ON kit_products;
DROP POLICY IF EXISTS "kit_products_insert_admin" ON kit_products;
DROP POLICY IF EXISTS "kit_products_update_admin" ON kit_products;
DROP POLICY IF EXISTS "kit_products_delete_admin" ON kit_products;

-- Public can view all products
CREATE POLICY "kit_products_select_all" ON kit_products
  FOR SELECT
  USING (true);

-- Only admins can insert/update/delete
CREATE POLICY "kit_products_insert_admin" ON kit_products
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "kit_products_update_admin" ON kit_products
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "kit_products_delete_admin" ON kit_products
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Updated_at trigger
DROP TRIGGER IF EXISTS kit_products_updated_at ON kit_products;
CREATE TRIGGER kit_products_updated_at
  BEFORE UPDATE ON kit_products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert initial product data
INSERT INTO kit_products (category, product_name, price, stripe_url, stock_xs, stock_s, stock_m, stock_l, stock_xl, stock_xxl) VALUES
-- Male Kit
('male', 'Vest (Standard)', 20.00, 'https://buy.stripe.com/4gwfZraNj5Ue60U3ci', 2, 3, 4, 4, 2, 1),
('male', 'Vest (Mid Range)', 34.00, 'https://buy.stripe.com/00gcNfaNj5Ue0GA00C', 0, 4, 0, 0, 0, 0),
('male', 'Vest (Premium)', 60.00, 'https://buy.stripe.com/8wMdRjaNj1DY74Y9Ba', 0, 0, 1, 1, 0, 0),
('male', 'Short Sleeve', 22.00, 'https://buy.stripe.com/bIYeVncVr5Ue1KE5kp', 3, 2, 3, 5, 3, 0),
('male', 'Long Sleeve', 20.00, 'https://buy.stripe.com/aEUcNf7B73M6fBucMQ', 3, 2, 4, 3, 3, 0),
('male', 'Shorts', 22.00, 'https://buy.stripe.com/eVabJb08Fbey4WQ7sZ', 0, 5, 4, 2, 5, 0),
('male', 'Jacket', 37.00, 'https://buy.stripe.com/9AQ8wZ3kRciC4WQfZx', 0, 4, 5, 5, 3, 0),
-- Female Kit
('female', 'Vest (Standard)', 20.00, 'https://buy.stripe.com/9AQ6oRg7D2I260U5kx', 4, 3, 5, 4, 1, 0),
('female', 'Vest (Mid Range)', 34.00, 'https://buy.stripe.com/dR68wZdZv0zU60UbJl', 0, 5, 4, 3, 0, 0),
('female', 'Vest (Premium)', 60.00, 'https://buy.stripe.com/dR6cNfcVrfuO60U7t3', 0, 2, 2, 0, 0, 0),
('female', 'Short Sleeve', 22.00, 'https://buy.stripe.com/28o3cF1cJeqKdtmaEP', 3, 3, 4, 5, 3, 0),
('female', 'Long Sleeve', 20.00, 'https://buy.stripe.com/cN214x9JfgySahaeV6', 4, 4, 3, 3, 3, 0),
('female', 'Shorts', 22.00, 'https://buy.stripe.com/9AQ28B5sZgyS8927sY', 2, 2, 9, 3, 0, 0),
('female', 'Jacket', 37.00, 'https://buy.stripe.com/eVa4gJ3kRgySdtm00y', 1, 2, 0, 2, 0, 0),
-- Hoodies
('hoodie', 'Zip Up Hoodie - Black', 32.00, 'https://buy.stripe.com/14kaF79Jf1DYgFy289', 3, 2, 3, 3, 3, 0),
('hoodie', 'Zip Up Hoodie - Blue', 32.00, 'https://buy.stripe.com/00gbJb8Fb3M6exq288', 3, 1, 3, 5, 3, 0),
('hoodie', 'Pullover Hoodie - Black', 32.00, 'https://buy.stripe.com/8wMcNf5sZ4Qa60U8wz', 3, 8, 13, 3, 3, 0),
('hoodie', 'Pullover Hoodie - Blue', 32.00, 'https://buy.stripe.com/bIYaF7f3zfuO2OI5km', 5, 2, 4, 7, 3, 1)
ON CONFLICT DO NOTHING;
