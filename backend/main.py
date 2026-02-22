"""
ElderCare AI – FastAPI Backend (Production Hardened)

Changes:
- Removed raw stack trace from 500 responses
- Added request_id (UUID) per request
- Added latency tracking
- Structured JSON-style logging
- Fixed DB session handling in decay loop
"""
import asyncio
import uuid
import time
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from database.engine import engine, Base, SessionLocal
from routers import auth, risk, sms, voice, alerts, sos, call_protection, contacts, health, guardian
from services.risk_service import decay_all_scores

# ── Structured Logging Setup ──
logger = logging.getLogger("eldercare")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter(
    '%(asctime)s [%(levelname)s] %(message)s'
))
logger.addHandler(handler)

# Create all tables
Base.metadata.create_all(bind=engine)


# ── Background decay scheduler ─────────────────────────
async def _decay_loop():
    """Run decay_all_scores every hour."""
    while True:
        db = None
        try:
            db = SessionLocal()
            decay_all_scores(db)
            logger.info("Risk decay cycle completed")
        except Exception as e:
            logger.error(f"Decay scheduler error: {e}")
        finally:
            if db:
                db.close()
        await asyncio.sleep(3600)  # 1 hour


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup/shutdown lifecycle — starts the decay background task."""
    task = asyncio.create_task(_decay_loop())
    logger.info("Risk decay scheduler started (every 1 hour)")
    yield
    task.cancel()


app = FastAPI(
    title="ElderCare AI API",
    description="Backend API for Elder Fraud Protection System",
    version="2.1.0",
    lifespan=lifespan,
)

# CORS – allow Flutter web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # TODO: Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def structured_logging_middleware(request: Request, call_next):
    """Production middleware: request_id, latency tracking, NO stack traces in response."""
    request_id = str(uuid.uuid4())[:8]
    start_time = time.time()

    # Attach request_id for downstream use
    request.state.request_id = request_id

    logger.info(f"[{request_id}] {request.method} {request.url.path}")

    try:
        response = await call_next(request)
        latency_ms = int((time.time() - start_time) * 1000)
        logger.info(f"[{request_id}] {response.status_code} ({latency_ms}ms)")
        response.headers["X-Request-ID"] = request_id
        return response
    except Exception as exc:
        latency_ms = int((time.time() - start_time) * 1000)
        logger.error(f"[{request_id}] 500 Internal Server Error ({latency_ms}ms): {type(exc).__name__}: {exc}")
        # NEVER expose stack traces to client
        return JSONResponse(
            status_code=500,
            content={
                "detail": "Internal server error. Please try again.",
                "request_id": request_id,
            },
            headers={"X-Request-ID": request_id},
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
app.include_router(guardian.router, prefix="", tags=["Guardian"])


@app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "app": "ElderCare AI", "version": "2.1.0"}