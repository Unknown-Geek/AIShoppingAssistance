import json
import os

def generate_sql():
    # Load JSON data from relative path
    json_path = 'inventory.json'
    if not os.path.exists(json_path):
        # Fallback if run from scripts/ directory
        json_path = '../inventory.json'
        
    with open(json_path, 'r') as f:
        data = json.load(f)
        
    items = data.get('items', [])
    
    sql_lines = []
    sql_lines.append("-- 1. Create the inventory table")
    sql_lines.append("CREATE TABLE IF NOT EXISTS public.inventory (")
    sql_lines.append("  sku TEXT PRIMARY KEY,")
    sql_lines.append("  slug TEXT NOT NULL UNIQUE,")
    sql_lines.append("  name TEXT NOT NULL,")
    sql_lines.append("  price_rupees NUMERIC NOT NULL,")
    sql_lines.append("  staging_dirs TEXT[] NOT NULL,")
    sql_lines.append("  image_url TEXT,")
    sql_lines.append("  created_at TIMESTAMPTZ DEFAULT NOW()")
    sql_lines.append(");\n")
    
    sql_lines.append("-- Enable row level security (optional, but recommended)")
    sql_lines.append("ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;")
    sql_lines.append("CREATE POLICY \"Allow public read access\" ON public.inventory FOR SELECT USING (true);\n")
    
    sql_lines.append("-- 2. Insert items")
    sql_lines.append("INSERT INTO public.inventory (sku, slug, name, price_rupees, staging_dirs, image_url)")
    sql_lines.append("VALUES")
    
    value_clauses = []
    for item in items:
        sku = item['sku'].replace("'", "''")
        slug = item['slug'].replace("'", "''")
        name = item['name'].replace("'", "''")
        price = item['price_rupees']
        img_url = item.get('image_url', '').replace("'", "''")
        
        # Build array literal string
        dirs = []
        for d in item['staging_dirs']:
            clean_d = d.replace("'", "''")
            dirs.append(f"'{clean_d}'")
        dirs_formatted = ", ".join(dirs)
        dirs_array = f"ARRAY[{dirs_formatted}]"
        
        value_clauses.append(f"  ('{sku}', '{slug}', '{name}', {price}, {dirs_array}, '{img_url}')")
        
    sql_lines.append(",\n".join(value_clauses) + ";")
    
    # Write to target seed file
    artifacts_dir = 'artifacts'
    if not os.path.exists('pubspec.yaml') and os.path.exists('../pubspec.yaml'):
        artifacts_dir = '../artifacts'
        
    os.makedirs(artifacts_dir, exist_ok=True)
    output_path = os.path.join(artifacts_dir, 'supabase_seed.sql')
    with open(output_path, 'w') as out_f:
        out_f.write("\n".join(sql_lines))
    print(f"SQL seed script successfully written to {output_path}")

if __name__ == '__main__':
    generate_sql()
