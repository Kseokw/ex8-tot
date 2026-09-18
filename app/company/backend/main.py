from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
from sqlalchemy import text

from db import engine, init_db

GRADES_PAGE = Path(__file__).parent / "static" / "grades.html"


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()  # 기동 시 테이블 생성
    yield


app = FastAPI(title="company-backend", lifespan=lifespan)


class StudentIn(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    course: str = Field(min_length=1, max_length=50)
    score: int = Field(ge=0, le=100)


class ScoreUpdate(BaseModel):
    score: int = Field(ge=0, le=100)


# ------------------------------- 상태 확인 -------------------------------
@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.get("/api/db/health")
def db_health():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return {"database": "ok"}
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=503, detail=f"DB 연결 실패: {exc}")


# ------------------------------- 성적 조회 페이지 -------------------------------
@app.get("/grades", response_class=HTMLResponse)
def grades_page():
    return GRADES_PAGE.read_text(encoding="utf-8")


# ------------------------------- 성적 CRUD -------------------------------
@app.get("/api/students")
def list_students(name: str | None = None, course: str | None = None):
    sql = "SELECT id, name, course, score, updated_at FROM students"
    where, params = [], {}
    if name:
        where.append("name LIKE :name")
        params["name"] = f"%{name}%"
    if course:
        where.append("course LIKE :course")
        params["course"] = f"%{course}%"
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY id DESC"

    with engine.connect() as conn:
        rows = conn.execute(text(sql), params).mappings().all()
    return [dict(row) for row in rows]


@app.post("/api/students", status_code=201)
def create_student(student: StudentIn):
    with engine.begin() as conn:
        result = conn.execute(
            text(
                "INSERT INTO students (name, course, score) "
                "VALUES (:name, :course, :score)"
            ),
            student.model_dump(),
        )
        new_id = result.lastrowid
    return {"id": new_id, **student.model_dump()}


@app.put("/api/students/{student_id}")
def update_score(student_id: int, payload: ScoreUpdate):
    with engine.begin() as conn:
        result = conn.execute(
            text("UPDATE students SET score = :score WHERE id = :id"),
            {"score": payload.score, "id": student_id},
        )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="해당 교육생이 없습니다.")
    return {"id": student_id, "score": payload.score}


@app.delete("/api/students/{student_id}", status_code=204)
def delete_student(student_id: int):
    with engine.begin() as conn:
        result = conn.execute(
            text("DELETE FROM students WHERE id = :id"), {"id": student_id}
        )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="해당 교육생이 없습니다.")
