import mysql.connector
from mysql.connector import pooling
import os
from dotenv import load_dotenv

load_dotenv()


_pool = None

def get_pool():
    global _pool
    if _pool is None:
        _pool = pooling.MySQLConnectionPool(
            pool_name="smart_parking_pool",
            pool_size=10,
            host=os.getenv('DB_HOST', 'localhost'),
            port=int(os.getenv('DB_PORT', 3306)),
            user=os.getenv('DB_USER', 'root'),
            password=os.getenv('DB_PASSWORD', ''),
            database=os.getenv('DB_NAME', 'smart_parking_db'),
            charset='utf8mb4',
            collation='utf8mb4_unicode_ci',
            autocommit=False,
        )
    return _pool

def get_db():
    return get_pool().get_connection()

def execute_query(query, params=None, fetch=True, commit=False):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(query, params or ())
        if commit:
            conn.commit()
            return cursor.lastrowid
        if fetch:
            return cursor.fetchall()
        return None
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()

def execute_one(query, params=None):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(query, params or ())
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()
