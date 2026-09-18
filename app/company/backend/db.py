import os
import time

from sqlalchemy import create_engine, text

DB_HOST = os.getenv("DB_HOST", "mysql")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_NAME = os.getenv("DB_NAME", "grades")
DB_USER = os.getenv("DB_USER", "dbadmin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "localpassword")

DB_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"

# pool_pre_ping: 끊긴 커넥션을 자동으로 걸러낸다
engine = create_engine(DB_URL, pool_pre_ping=True, pool_recycle=280, future=True)

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS students (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    course     VARCHAR(50) NOT NULL,
    score      INT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
"""


def init_db(retries: int = 30, delay: int = 5) -> None:
    """DB 가 준비될 때까지 기다렸다가 테이블을 생성한다."""
    last_error = None
    for attempt in range(1, retries + 1):
        try:
            with engine.begin() as conn:
                conn.execute(text(CREATE_TABLE_SQL))
            print(f"[db] 준비 완료 ({attempt}번째 시도)")
            return
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            print(f"[db] 연결 대기 중... ({attempt}/{retries}) {exc}")
            time.sleep(delay)
    raise RuntimeError(f"DB 초기화 실패: {last_error}")
