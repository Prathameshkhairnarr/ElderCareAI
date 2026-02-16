"""
ElderCare AI – FastAPI Backend
"""
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from database.engine import engine, Base
from routers import auth, risk, sms, voice, alerts, sos, call_protection, contacts, health

# Create all tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="ElderCare AI API",
    description="Backend API for Elder Fraud Protection System",
    version="2.0.0",
)

# CORS – allow Flutter web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def catch_exceptions_middleware(request: Request, call_next):
    print(f"📥 REQUEST: {request.method} {request.url}")
    try:
        response = await call_next(request)
        print(f"📤 RESPONSE: {response.status_code}")
        return response
    except Exception as exc:
        import traceback
        error_trace = traceback.format_exc()
        print(error_trace)
        return JSONResponse(
            status_code=500, 
            content={"detail": str(exc), "trace": error_trace}
        )

# Include routers with prefixes
app.include_router(auth.router)  # auth router already has prefix="/auth"
app.include_router(sms.router, prefix="/sms", tags=["SMS Analysis"])
app.include_router(contacts.router, prefix="/contacts", tags=["Emergency Contacts"])
app.include_router(health.router, prefix="/health", tags=["Health Monitor"])
app.include_router(risk.router, prefix="", tags=["Risk Score"])
app.include_router(alerts.router, prefix="", tags=["Alerts"])
app.include_router(sos.router, prefix="", tags=["SOS"])  # /sos at root
app.include_router(call_protection.router, prefix="/call", tags=["Call Protection"])


@app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "app": "ElderCare AI", "version": "2.0.0"}