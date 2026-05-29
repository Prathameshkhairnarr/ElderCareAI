"""
Edge TTS Router — Free Microsoft Neural TTS via edge-tts library.

Provides the same high-quality neural voices as Azure Speech Service
but without requiring a subscription key. Uses Microsoft Edge's
read-aloud API internally.

Endpoint: POST /tts/synthesize
"""
import asyncio
import io
import edge_tts
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/tts", tags=["Edge TTS"])


class TTSRequest(BaseModel):
    """Request body for Edge TTS synthesis."""
    text: str = Field(..., min_length=1, max_length=5000)
    voice: str = Field(default="hi-IN-SwaraNeural")
    rate: str = Field(default="-8%")
    pitch: str = Field(default="+2Hz")


@router.post("/synthesize")
async def synthesize_speech(request: TTSRequest):
    """
    Synthesize text to MP3 audio using Edge TTS.
    
    Returns raw MP3 audio bytes as streaming response.
    Same neural voices as Azure (hi-IN-SwaraNeural, en-IN-NeerjaNeural, etc.)
    """
    try:
        communicate = edge_tts.Communicate(
            text=request.text,
            voice=request.voice,
            rate=request.rate,
            pitch=request.pitch,
        )
        
        # Collect audio bytes
        audio_buffer = io.BytesIO()
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_buffer.write(chunk["data"])
        
        audio_buffer.seek(0)
        
        if audio_buffer.getbuffer().nbytes == 0:
            raise HTTPException(status_code=500, detail="Empty audio generated")
        
        return StreamingResponse(
            audio_buffer,
            media_type="audio/mpeg",
            headers={
                "Content-Disposition": "inline; filename=tts_output.mp3",
                "Cache-Control": "public, max-age=3600",
            },
        )
    except edge_tts.exceptions.NoAudioReceived:
        raise HTTPException(status_code=400, detail="No audio generated for given text")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"TTS synthesis failed: {str(e)}")


@router.get("/voices")
async def list_voices():
    """List available Edge TTS voices (filtered for Indian languages)."""
    try:
        voices = await edge_tts.list_voices()
        indian_voices = [
            {"name": v["Name"], "gender": v["Gender"], "locale": v["Locale"]}
            for v in voices
            if v["Locale"].startswith("hi-") or v["Locale"].startswith("en-IN")
        ]
        return {"voices": indian_voices}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list voices: {str(e)}")
