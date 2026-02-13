"""
ElderCare AI – FastAPI Backend
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database.engine import engine, Base
from routers import auth, risk, sms, voice, alerts, sos

# Create all tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="ElderCare AI API",
    description="Backend API for Elder Fraud Protection System",
    version="1.0.0",
)

# CORS – allow Flutter web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(risk.router)
app.include_router(sms.router)
app.include_router(voice.router)
app.include_router(alerts.router)
app.include_router(sos.router)


@app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "app": "ElderCare AI", "version": "1.0.0"}
