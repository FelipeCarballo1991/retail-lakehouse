"""
Genera todos los archivos de la landing_zone del proyecto "Retail Lakehouse".
Cubre los 4 cursos de la ruta Databricks Data Engineer:
  - orders/status        -> Build Data Pipelines with SDP (Guías 1-5)
  - customers            -> CDC / AUTO CDC INTO SCD Type 1 (Guías 1-5)
  - employees            -> CDC lab con CSV (Guías 1-5)
  - products             -> Data Ingestion with LakeFlow Connect (CTAS/COPY INTO/Auto Loader/MERGE INTO)
  - products_incremental  -> segunda carga para demostrar incrementalidad e idempotencia
Ejecutar: python scripts/generate_landing_zone.py
"""
import json, csv, random, os
from datetime import datetime, timedelta

import pandas as pd

random.seed(42)
BASE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "landing_zone")

def w_jsonl(path, records):
    with open(path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

def w_csv(path, header, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)

# =================================================================
# 1. ORDERS  (para Streaming Tables / Materialized Views - Guía SDP)
# =================================================================
base = datetime(2026, 6, 1, 9, 0, 0)
orders_00 = []
for i in range(1, 21):
    ts = base + timedelta(hours=i * 3, minutes=random.randint(0, 59))
    orders_00.append({
        "order_id": 5000 + i,
        "order_timestamp": ts.strftime("%Y-%m-%dT%H:%M:%S"),
        "customer_id": 1000 + (i % 12),
        "store_region": random.choice(["CABA", "Cordoba", "Mendoza", "Rosario"]),
        "notifications": random.choice(["Y", "N"])
    })
w_jsonl(f"{BASE}/orders/orders_00.json", orders_00)

orders_01 = []
base2 = base + timedelta(days=3)
for i in range(21, 27):
    ts = base2 + timedelta(hours=i, minutes=random.randint(0, 59))
    orders_01.append({
        "order_id": 5000 + i,
        "order_timestamp": ts.strftime("%Y-%m-%dT%H:%M:%S"),
        "customer_id": 1000 + (i % 12),
        "store_region": random.choice(["CABA", "Cordoba", "Mendoza", "Rosario"]),
        "notifications": random.choice(["Y", "N"])
    })
w_jsonl(f"{BASE}/orders/orders_01.json", orders_01)

# =================================================================
# 2. STATUS
# =================================================================
STATUSES_HAPPY = ["placed", "preparing", "on the way", "delivered"]
STATUSES_CANCEL = ["placed", "preparing", "canceled"]

def gen_status(order, start_ts):
    path = STATUSES_CANCEL if random.random() < 0.15 else STATUSES_HAPPY
    out, t = [], start_ts
    for st in path:
        t = t + timedelta(hours=random.randint(1, 10))
        out.append({"order_id": order["order_id"], "order_status": st,
                    "status_timestamp": t.strftime("%Y-%m-%dT%H:%M:%S")})
    return out

status_00, status_01 = [], []
for o in orders_00:
    status_00.extend(gen_status(o, datetime.strptime(o["order_timestamp"], "%Y-%m-%dT%H:%M:%S")))
for o in orders_01:
    status_01.extend(gen_status(o, datetime.strptime(o["order_timestamp"], "%Y-%m-%dT%H:%M:%S")))
w_jsonl(f"{BASE}/status/status_00.json", status_00)
w_jsonl(f"{BASE}/status/status_01.json", status_01)

# =================================================================
# 3. CUSTOMERS (CDC feed -> AUTO CDC INTO, SCD Type 1/2)
# =================================================================
FIRST = ["Sofia","Mateo","Valentina","Lucas","Emma","Thiago","Martina","Benjamin",
         "Isabella","Santiago","Catalina","Joaquin","Renata","Nicolas","Julieta","Franco"]
LAST = ["Gomez","Fernandez","Rodriguez","Lopez","Diaz","Martinez","Perez","Sosa",
        "Romero","Alvarez","Torres","Ruiz","Flores","Acosta","Benitez","Silva"]
STATES = ["BA","CBA","SF","MZA","TUC"]
CITIES = {"BA":"CABA","CBA":"Cordoba","SF":"Santa Fe","MZA":"Mendoza","TUC":"Tucuman"}
def epoch(dt): return int(dt.timestamp())

customers_00, c_base = [], datetime(2026, 6, 1, 8, 0, 0)
for i in range(1, 21):
    name = f"{random.choice(FIRST)} {random.choice(LAST)}"
    state = random.choice(STATES)
    ts = c_base + timedelta(minutes=i * 7)
    customers_00.append({
        "customer_id": 1000 + i, "name": name,
        "address": f"{random.randint(100,9999)} Av. Siempre Viva",
        "city": CITIES[state], "state": state, "zip_code": f"{random.randint(1000,9999)}",
        "email": name.lower().replace(" ", ".") + "@example.com",
        "timestamp": epoch(ts), "operation": "NEW"
    })
w_jsonl(f"{BASE}/customers/customers_00.json", customers_00)

c_base2 = c_base + timedelta(days=5)
customers_01, update_ids = [], [1002, 1005, 1007, 1010, 1011]
for idx, cid in enumerate(update_ids):
    orig = next(c for c in customers_00 if c["customer_id"] == cid)
    ts = c_base2 + timedelta(minutes=idx * 11)
    customers_01.append({
        "customer_id": cid, "name": orig["name"],
        "address": f"{random.randint(100,9999)} Av. Corrientes",
        "city": orig["city"], "state": orig["state"], "zip_code": f"{random.randint(1000,9999)}",
        "email": orig["email"], "timestamp": epoch(ts), "operation": "UPDATE"
    })
del_ts = c_base2 + timedelta(minutes=70)
customers_01.append({"customer_id": 1003, "name": None, "address": None, "city": None,
                      "state": None, "zip_code": None, "email": None,
                      "timestamp": epoch(del_ts), "operation": "DELETE"})
for j, i in enumerate(range(21, 25)):
    name = f"{random.choice(FIRST)} {random.choice(LAST)}"
    state = random.choice(STATES)
    ts = c_base2 + timedelta(minutes=80 + j * 9)
    customers_01.append({
        "customer_id": 1000 + i, "name": name,
        "address": f"{random.randint(100,9999)} Av. Siempre Viva",
        "city": CITIES[state], "state": state, "zip_code": f"{random.randint(1000,9999)}",
        "email": name.lower().replace(" ", ".") + "@example.com",
        "timestamp": epoch(ts), "operation": "NEW"
    })
w_jsonl(f"{BASE}/customers/customers_01.json", customers_01)

# =================================================================
# 4. EMPLOYEES CSV (CDC lab - empleados de tienda)
# =================================================================
emp_header = ["EmployeeID","FirstName","Country","Department","Salary","HireDate","Operation","ProcessDate"]
employees_1 = [
    [1,"Sophia","AR","Sales",900000,"2025-01-15","insert","2025-06-05"],
    [2,"Nikos","AR","IT",750000,"2025-04-10","insert","2025-06-05"],
    [3,"Liam","AR","Sales",950000,"2025-05-03","insert","2025-06-05"],
    [4,"Elena","AR","IT",730000,"2025-06-04","insert","2025-06-05"],
    [5,"James","AR","IT",800000,"2025-06-05","insert","2025-06-05"],
    [9,"Maria","AR","Finance",780000,"2025-02-20","insert","2025-06-05"],
]
employees_2 = [
    [1,"","","","","","delete","2025-06-22"],
    [3,"Liam","AR","Sales",1000000,"2025-05-03","update","2025-06-22"],
    [6,"Emily","AR","Enablement",800000,"2025-06-09","insert","2025-06-22"],
    [7,"Yannis","AR","HR",700000,"2025-06-20","insert","2025-06-22"],
]
w_csv(f"{BASE}/employees/employees_1.csv", emp_header, employees_1)
w_csv(f"{BASE}/employees/employees_2.csv", emp_header, employees_2)

# =================================================================
# 5. PRODUCTS (Parquet) -> Guía Data Ingestion: CTAS / COPY INTO / Auto Loader / MERGE INTO
# =================================================================
CATEGORIES = ["Electronica", "Hogar", "Indumentaria", "Alimentos", "Juguetes", "Deportes"]
products_initial = []
for i in range(1, 51):
    products_initial.append({
        "product_id": 100 + i,
        "product_name": f"Producto {100+i}",
        "category": random.choice(CATEGORIES),
        "price": round(random.uniform(500, 50000), 2),
        "stock": random.randint(0, 500),
        "active": True
    })
df_products = pd.DataFrame(products_initial)
os.makedirs(f"{BASE}/products", exist_ok=True)
df_products.to_parquet(f"{BASE}/products/part-00000.parquet", index=False)

# Segunda carga incremental (simula nuevos archivos llegando al storage -> COPY INTO / Auto Loader)
products_new = []
for i in range(51, 66):
    products_new.append({
        "product_id": 100 + i,
        "product_name": f"Producto {100+i}",
        "category": random.choice(CATEGORIES),
        "price": round(random.uniform(500, 50000), 2),
        "stock": random.randint(0, 500),
        "active": True
    })
df_products_new = pd.DataFrame(products_new)
os.makedirs(f"{BASE}/products_incremental", exist_ok=True)
df_products_new.to_parquet(f"{BASE}/products_incremental/part-00001.parquet", index=False)

# =================================================================
# 6. MERGE INTO demo: tabla target (catálogo actual) + tabla source (cambios entrantes)
# =================================================================
target_rows = []
for i in range(1, 9):
    target_rows.append({"product_id": 100+i, "product_name": f"Producto {100+i}",
                         "price": round(random.uniform(500,50000),2), "status": "current"})
df_target = pd.DataFrame(target_rows)
df_target.to_csv(f"{BASE}/products/merge_target_products.csv", index=False)

# source: 2 updates de precio, 1 delete (descontinuado), 2 altas nuevas
source_rows = [
    {"product_id": 102, "product_name": "Producto 102", "price": 15999.0, "status": "update"},
    {"product_id": 105, "product_name": "Producto 105", "price": 8999.0,  "status": "update"},
    {"product_id": 103, "product_name": "Producto 103", "price": None,   "status": "delete"},
    {"product_id": 200, "product_name": "Producto 200 Nuevo", "price": 25999.0, "status": "new"},
    {"product_id": 201, "product_name": "Producto 201 Nuevo", "price": 3999.0,  "status": "new"},
]
df_source = pd.DataFrame(source_rows)
df_source.to_csv(f"{BASE}/products/merge_source_products.csv", index=False)

print("Landing zone generada en:", BASE)
for root, dirs, files in os.walk(BASE):
    for f in sorted(files):
        print(" -", os.path.relpath(os.path.join(root, f), BASE))
